import { Controller } from "@hotwired/stimulus";

const SAVE_DELAY_MS = 300;
const NEEDLE_LENGTH = 24;
const MARK = "rgba(250, 204, 21, 0.35)";
const MAX_WIDTH = 1200;
const PNG_BUDGET = 500 * 1024;
const JPEG_QUALITY = 0.85;
const IMAGE_TYPES = ["image/png", "image/jpeg", "image/gif"];

export default class extends Controller {
  static targets = [
    "form",
    "editor",
    "frame",
    "status",
    "panel",
    "person",
    "count",
    "deliver",
  ];
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
    this.request?.abort();
    document.removeEventListener("trix-file-accept", this.accept);
    document.removeEventListener("trix-attachment-add", this.attach);
  }

  changed(event) {
    if (this.lockedValue) return;
    this.follow(event);
    clearTimeout(this.timer);
    this.timer = setTimeout(() => this.save(), SAVE_DELAY_MS);
  }

  follow(event) {
    const target = event?.target;
    if (target?.matches?.("input[type=text]")) this.needle = "";
    else if (target === this.editorTarget || this.editorTarget.contains(target))
      this.needle = this.caretText();
    else return;
    this.reveal();
  }

  audience(event) {
    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.mode !== event.target.value;
    });
  }

  filter(event) {
    const query = event.target.value.trim().toLowerCase();
    this.personTargets.forEach((person) => {
      person.hidden = query !== "" && !person.dataset.search.includes(query);
    });
  }

  async save() {
    this.request?.abort();
    const request = new AbortController();
    this.request = request;
    try {
      const response = await fetch(this.formTarget.action, {
        method: "POST",
        body: new FormData(this.formTarget),
        headers: { Accept: "application/json", "X-CSRF-Token": this.token() },
        signal: request.signal,
      });
      if (!response.ok) throw new Error(String(response.status));
      const { html, recipients, deliver, confirm } = await response.json();
      this.render(html);
      this.audienceSaved(recipients, deliver, confirm);
      this.statusTarget.textContent = `${this.savedLabelValue} ${new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}`;
    } catch (error) {
      if (error.name !== "AbortError")
        this.statusTarget.textContent = this.failedLabelValue;
    }
  }

  render(html) {
    const view = this.frameTarget.contentDocument;
    if (!view?.body) {
      this.frameTarget.srcdoc = html;
      return;
    }
    const fresh = new DOMParser().parseFromString(html, "text/html");
    const top = view.defaultView.scrollY;
    view.title = fresh.title;
    view.body.replaceWith(view.importNode(fresh.body, true));
    view.defaultView.scrollTo(0, top);
    this.reveal();
  }

  audienceSaved(recipients, deliver, confirm) {
    if (this.hasCountTarget && recipients)
      this.countTarget.textContent = recipients;
    if (!this.hasDeliverTarget || !deliver) return;
    this.deliverTarget.dataset.turboConfirm = confirm;
    const button = this.deliverTarget.querySelector("button, [type=submit]");
    if (button) button.textContent = deliver;
  }

  caretText() {
    const selection = window.getSelection();
    const node = selection?.anchorNode;
    if (!node || node.nodeType !== Node.TEXT_NODE) {
      const block =
        node?.nodeType === Node.ELEMENT_NODE ? node : node?.parentElement;
      return this.squash(block?.textContent || "").slice(0, NEEDLE_LENGTH);
    }
    const text = node.textContent;
    const start = Math.max(0, selection.anchorOffset - NEEDLE_LENGTH);
    const before = this.squash(text.slice(start, selection.anchorOffset));
    return before.length >= 4
      ? before
      : this.squash(text).slice(0, NEEDLE_LENGTH);
  }

  reveal() {
    const view = this.frameTarget.contentDocument;
    const win = view?.defaultView;
    if (!view?.body || !win) return;
    if (this.marked) this.marked.style.backgroundColor = "";
    this.marked = null;
    if (!this.needle) {
      if (this.needle === "") win.scrollTo({ top: 0, behavior: "smooth" });
      return;
    }
    const element = this.locate(view, this.needle);
    if (!element) return;
    element.style.backgroundColor = MARK;
    this.marked = element;
    const box = element.getBoundingClientRect();
    const top = box.top + win.scrollY - win.innerHeight / 2 + box.height / 2;
    win.scrollTo({ top: Math.max(0, top), behavior: "smooth" });
  }

  locate(view, needle) {
    const walker = view.createTreeWalker(view.body, NodeFilter.SHOW_TEXT);
    const short = needle.slice(-8);
    let fallback = null;
    for (let node = walker.nextNode(); node; node = walker.nextNode()) {
      const text = this.squash(node.textContent);
      if (text.includes(needle)) return node.parentElement;
      if (!fallback && short.length >= 4 && text.includes(short))
        fallback = node.parentElement;
    }
    return fallback;
  }

  squash(text) {
    return text.replace(/\s+/g, " ").trim();
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
