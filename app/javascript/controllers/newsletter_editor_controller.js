import { Controller } from "@hotwired/stimulus";

const SAVE_DELAY_MS = 800;
const MAX_WIDTH = 1200;
const PNG_BUDGET = 500 * 1024;
const JPEG_QUALITY = 0.85;
const IMAGE_TYPES = ["image/png", "image/jpeg", "image/gif"];

export default class extends Controller {
  static targets = ["form", "editor", "frame", "status"];
  static values = {
    uploadUrl: String,
    locked: Boolean,
    savedLabel: String,
    failedLabel: String,
    imageFailedLabel: String,
  };

  async connect() {
    this.accept = (event) => this.acceptFile(event);
    this.attach = (event) => this.upload(event.attachment);
    document.addEventListener("trix-file-accept", this.accept);
    document.addEventListener("trix-attachment-add", this.attach);
    await import("trix");
    if (this.lockedValue && this.hasEditorTarget)
      this.editorTarget.contentEditable = "false";
  }

  disconnect() {
    clearTimeout(this.timer);
    document.removeEventListener("trix-file-accept", this.accept);
    document.removeEventListener("trix-attachment-add", this.attach);
  }

  changed() {
    if (this.lockedValue) return;
    clearTimeout(this.timer);
    this.timer = setTimeout(() => this.save(), SAVE_DELAY_MS);
  }

  async save() {
    try {
      const response = await fetch(this.formTarget.action, {
        method: "POST",
        body: new FormData(this.formTarget),
        headers: { Accept: "application/json", "X-CSRF-Token": this.token() },
      });
      if (!response.ok) throw new Error(String(response.status));
      const { html } = await response.json();
      this.frameTarget.srcdoc = html;
      this.statusTarget.textContent = `${this.savedLabelValue} ${new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}`;
    } catch {
      this.statusTarget.textContent = this.failedLabelValue;
    }
  }

  acceptFile(event) {
    if (this.lockedValue || !IMAGE_TYPES.includes(event.file?.type))
      event.preventDefault();
  }

  async upload(attachment) {
    if (!attachment.file) return;
    try {
      const file = await this.shrink(attachment.file);
      const body = new FormData();
      body.append("file", file, file.name);
      const response = await fetch(this.uploadUrlValue, {
        method: "POST",
        body,
        headers: { Accept: "application/json", "X-CSRF-Token": this.token() },
      });
      if (!response.ok) throw new Error(String(response.status));
      const { url } = await response.json();
      attachment.setUploadProgress(100);
      attachment.setAttributes({ url });
    } catch {
      attachment.remove();
      this.statusTarget.textContent = this.imageFailedLabelValue;
    }
  }

  async shrink(file) {
    if (file.type === "image/gif") return file;
    const bitmap = await createImageBitmap(file);
    const scale = Math.min(1, MAX_WIDTH / bitmap.width);
    const canvas = document.createElement("canvas");
    canvas.width = Math.round(bitmap.width * scale);
    canvas.height = Math.round(bitmap.height * scale);
    const context = canvas.getContext("2d");
    context.fillStyle = "#ffffff";
    context.fillRect(0, 0, canvas.width, canvas.height);
    context.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
    bitmap.close();

    const png = await this.encode(canvas, "image/png");
    if (png.size <= PNG_BUDGET)
      return new File([png], "image.png", { type: "image/png" });

    const jpeg = await this.encode(canvas, "image/jpeg", JPEG_QUALITY);
    return new File([jpeg], "image.jpg", { type: "image/jpeg" });
  }

  encode(canvas, type, quality) {
    return new Promise((resolve, reject) =>
      canvas.toBlob(
        (blob) => (blob ? resolve(blob) : reject(new Error("encode"))),
        type,
        quality,
      ),
    );
  }

  token() {
    return document.querySelector('meta[name="csrf-token"]')?.content || "";
  }
}
