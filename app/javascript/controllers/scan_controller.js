import { Controller } from "@hotwired/stimulus";
import { csrfToken } from "lib/csrf";
import { shrinkImage } from "lib/image_shrink";

const POLL_DELAYS = [1200, 1200, 1500, 2000, 2000, 3000];
const POLL_LIMIT_MS = 200000;

export default class extends Controller {
  static targets = [
    "remaining",
    "picker",
    "zone",
    "progress",
    "preview",
    "status",
    "error",
    "result",
    "note",
    "changed",
    "text",
    "title",
    "again",
  ];
  static values = {
    uploadUrl: String,
    edge: Number,
    maxBytes: Number,
    minEdge: Number,
    maxParts: Number,
    tallRatio: Number,
    remaining: Number,
    messages: Object,
  };

  connect() {
    this.busy = false;
    this.remaining = this.remainingValue;
    this.onPaste = this.paste.bind(this);
    document.addEventListener("paste", this.onPaste);
  }

  disconnect() {
    document.removeEventListener("paste", this.onPaste);
    this.stop();
    this.forgetPreview();
  }

  pick(event) {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (file) this.start(file);
  }

  hover(event) {
    event.preventDefault();
    this.zoneTarget.classList.add("border-primary");
  }

  leave() {
    this.zoneTarget.classList.remove("border-primary");
  }

  drop(event) {
    event.preventDefault();
    this.leave();
    const file = [...(event.dataTransfer?.files || [])].find((item) =>
      item.type.startsWith("image/"),
    );
    if (file) this.start(file);
    else this.fail(this.say("not_image"));
  }

  paste(event) {
    if (this.pickerTarget.hidden) return;
    const item = [...(event.clipboardData?.items || [])].find(
      (entry) => entry.kind === "file" && entry.type.startsWith("image/"),
    );
    if (!item) return;
    event.preventDefault();
    this.start(item.getAsFile());
  }

  async start(file) {
    if (this.busy || !file) return;
    if (file.type && !file.type.startsWith("image/"))
      return this.fail(this.say("not_image"));

    this.busy = true;
    this.clear();
    this.pickerTarget.hidden = true;
    this.showProgress(file, this.say("preparing"));

    let blobs;
    try {
      blobs = await shrinkImage(file, {
        edge: this.edgeValue,
        maxBytes: this.maxBytesValue,
        minEdge: this.minEdgeValue,
        maxParts: this.maxPartsValue,
        tallRatio: this.tallRatioValue,
      });
    } catch (error) {
      return this.fail(this.say(error.message) || this.say("not_image"));
    }

    this.statusTarget.textContent = this.say("sending");
    await this.upload(blobs);
  }

  async upload(blobs) {
    const body = new FormData();
    blobs.forEach((blob, index) =>
      body.append("photos[]", blob, `scan-${index + 1}.jpg`),
    );

    let response;
    let reply;
    try {
      response = await fetch(this.uploadUrlValue, {
        method: "POST",
        credentials: "same-origin",
        headers: { Accept: "application/json", "X-CSRF-Token": csrfToken() },
        body,
      });
      reply = await response.json();
    } catch (_) {
      return this.fail(this.say(response ? "generic" : "offline"));
    }

    this.count(reply);
    if (!response.ok) return this.fail(reply.message || this.say("generic"));

    this.statusTarget.textContent = this.say("reading");
    this.poll(reply.poll, 0, Date.now());
  }

  poll(url, attempt, started) {
    if (Date.now() - started > POLL_LIMIT_MS)
      return this.fail(this.say("generic"));

    const delay = POLL_DELAYS[Math.min(attempt, POLL_DELAYS.length - 1)];
    this.timer = setTimeout(async () => {
      let reply;
      try {
        const response = await fetch(url, {
          credentials: "same-origin",
          cache: "no-store",
          headers: { Accept: "application/json" },
        });
        if (!response.ok) return this.fail(this.say("generic"));
        reply = await response.json();
      } catch (_) {
        return this.poll(url, attempt + 1, started);
      }

      if (reply.state === "pending")
        return this.poll(url, attempt + 1, started);
      this.count(reply);
      if (reply.state === "done") return this.show(reply);
      this.fail(reply.message || this.say("generic"));
    }, delay);
  }

  show(reply) {
    this.busy = false;
    this.progressTarget.hidden = true;
    this.forgetPreview();
    this.resultTarget.hidden = false;
    this.textTarget.value = reply.text || "";
    this.reveal(this.noteTarget, reply.note);
    this.reveal(this.changedTarget, reply.changed);
    this.againTarget.hidden = this.remaining === 0;
    const empty = !reply.text;
    this.resultTarget
      .querySelectorAll("form button[type=submit]")
      .forEach((button) => (button.disabled = empty));
    if (!empty) this.textTarget.focus({ preventScroll: true });
  }

  fill(event) {
    const text = this.textTarget.value.trim();
    if (!text) {
      event.preventDefault();
      return;
    }
    const form = event.target;
    const file = form.querySelector("[data-scan-role=file]");
    if (file && this.attach(file, text)) {
      form.querySelector("[data-scan-role=text]").value = "";
    } else {
      form.querySelector("[data-scan-role=text]").value = text;
    }
    form.querySelector("[data-scan-role=title]").value =
      this.titleTarget.value.trim();
  }

  attach(input, text) {
    try {
      const transfer = new DataTransfer();
      transfer.items.add(new File([text], "scan.txt", { type: "text/plain" }));
      input.files = transfer.files;
      return input.files.length === 1;
    } catch (_) {
      return false;
    }
  }

  reset() {
    this.stop();
    this.clear();
    this.resultTarget.hidden = true;
    this.textTarget.value = "";
    this.pickerTarget.hidden = this.remaining === 0;
  }

  fail(message) {
    this.stop();
    this.busy = false;
    this.progressTarget.hidden = true;
    this.forgetPreview();
    this.reveal(this.errorTarget, message);
    this.pickerTarget.hidden = this.remaining === 0;
  }

  count(reply) {
    if (typeof reply?.remaining !== "number") return;
    this.remaining = reply.remaining;
    if (reply.remaining_label)
      this.remainingTarget.textContent = reply.remaining_label;
  }

  showProgress(file, message) {
    this.forgetPreview();
    this.previewUrl = URL.createObjectURL(file);
    this.previewTarget.src = this.previewUrl;
    this.statusTarget.textContent = message;
    this.progressTarget.hidden = false;
  }

  forgetPreview() {
    if (!this.previewUrl) return;
    URL.revokeObjectURL(this.previewUrl);
    this.previewUrl = null;
    this.previewTarget.removeAttribute("src");
  }

  clear() {
    this.reveal(this.errorTarget, null);
  }

  reveal(element, text) {
    element.textContent = text || "";
    element.hidden = !text;
  }

  stop() {
    clearTimeout(this.timer);
  }

  say(key) {
    return this.messagesValue[key];
  }
}
