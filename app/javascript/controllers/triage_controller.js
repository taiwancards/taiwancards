import { Controller } from "@hotwired/stimulus";
import { csrfToken } from "lib/csrf";
import { typingElsewhere } from "lib/hotkeys";

export default class extends Controller {
  static targets = [
    "card",
    "glyph",
    "reading",
    "counter",
    "known",
    "normal",
    "board",
    "summary",
    "left",
  ];
  static values = { items: Array, url: String };

  connect() {
    this.keyHandler = (event) => this.onKey(event);
    document.addEventListener("keydown", this.keyHandler);
    this.begin();
  }

  disconnect() {
    document.removeEventListener("keydown", this.keyHandler);
    this.flush({ keepalive: true });
  }

  begin() {
    this.queue = [...this.itemsValue];
    this.planned = this.queue.length;
    this.knownIds = [];
    this.normalIds = [];
    this.sentKnown = 0;
    this.sentNormal = 0;
    this.render();
  }

  render() {
    if (this.queue.length === 0) return this.finish();

    this.current = this.queue[0];
    this.glyphTarget.textContent = this.current.text;
    this.readingTarget.textContent = this.current.zhuyin || "";
    this.counterTarget.textContent = `${this.planned - this.queue.length} / ${this.planned}`;
    this.knownTarget.textContent = this.knownIds.length;
    this.normalTarget.textContent = this.normalIds.length;
    this.resetCard();
  }

  onKey(event) {
    if (typingElsewhere(event)) return;
    if (event.key === "ArrowRight") {
      event.preventDefault();
      this.mark(true);
    } else if (event.key === "ArrowLeft") {
      event.preventDefault();
      this.mark(false);
    }
  }

  markKnown() {
    this.mark(true);
  }

  markNormal() {
    this.mark(false);
  }

  mark(known) {
    if (!this.current) return;

    if (known) this.knownIds.push(this.current.id);
    else this.normalIds.push(this.current.id);

    this.queue.shift();
    this.render();
  }

  start(event) {
    if (event.target.closest("button, a")) return;
    this.startX = event.clientX;
    this.dragging = true;
  }

  move(event) {
    if (!this.dragging) return;
    const dx = event.clientX - this.startX;
    this.cardTarget.style.transition = "";
    this.cardTarget.style.transform = `translateX(${dx * 0.5}px) rotate(${dx * 0.02}deg)`;
  }

  end(event) {
    if (!this.dragging) return;
    this.dragging = false;
    const dx = event.clientX - this.startX;

    if (Math.abs(dx) < 40) return this.resetCard();
    this.mark(dx > 0);
  }

  resetCard() {
    this.cardTarget.style.transition = "transform 120ms ease-out";
    this.cardTarget.style.transform = "";
  }

  finish() {
    this.current = null;
    this.boardTarget.classList.add("hidden");
    this.summaryTarget.classList.remove("hidden");
    this.flush();
  }

  async flush({ keepalive = false } = {}) {
    if (this.flushing && !keepalive) return;
    const known = this.knownIds.slice(this.sentKnown);
    const normal = this.normalIds.slice(this.sentNormal);
    if (known.length === 0 && normal.length === 0) return;

    this.flushing = true;
    const response = await fetch(this.urlValue, {
      method: "POST",
      keepalive,
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken(),
      },
      body: JSON.stringify({ known, normal }),
    }).catch(() => null);
    this.flushing = false;
    if (!response?.ok) return;

    this.sentKnown += known.length;
    this.sentNormal += normal.length;
  }
}
