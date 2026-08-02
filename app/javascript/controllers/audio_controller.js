import { Controller } from "@hotwired/stimulus";

const LEAD_IN_MS = 140;
const STOP_GRACE_MS = 150;
const GAP_MS = 90;

export default class extends Controller {
  static values = { url: String, stopMs: Number, parts: Array, autoMs: Number };

  get sequence() {
    if (this.hasPartsValue && this.partsValue.length > 0)
      return this.partsValue;
    return [{ url: this.urlValue, stop_ms: this.stopMsValue }];
  }

  connect() {
    if (this.autoMsValue > 0)
      this.autoTimer = setTimeout(() => this.play(), this.autoMsValue);
  }

  disconnect() {
    if (this.autoTimer) clearTimeout(this.autoTimer);
    this.halt();
  }

  play(event) {
    event?.preventDefault();
    event?.stopPropagation();

    this.halt();
    this.queue = [...this.sequence];
    this.playNext();
  }

  playNext() {
    const next = this.queue?.shift();
    if (!next) return;

    this.current = next;
    this.sound = new Audio(next.url);
    this.sound.preload = "auto";
    this.sound.currentTime = 0;

    if (this.sound.readyState >= 3) return this.leadIn();

    this.ready = () => this.leadIn();
    this.sound.addEventListener("canplaythrough", this.ready, { once: true });
    this.sound.load();
  }

  leadIn() {
    this.leadTimer = setTimeout(() => this.start(), LEAD_IN_MS);
  }

  start() {
    if (!this.sound) return;

    this.sound.addEventListener("ended", () => this.advance(), { once: true });
    this.sound.play().catch(() => {});

    const stop = this.current?.stop_ms || 0;
    if (stop > 0) this.armStop(stop);
  }

  armStop(stopMs) {
    const limit = stopMs / 1000;

    this.watcher = () => {
      if (this.sound.currentTime >= limit) this.advance();
    };
    this.sound.addEventListener("timeupdate", this.watcher);

    this.timer = setTimeout(() => this.advance(), stopMs + STOP_GRACE_MS);
  }

  advance() {
    const more = this.queue?.length > 0;
    this.halt();
    if (more) this.gapTimer = setTimeout(() => this.playNext(), GAP_MS);
  }

  halt() {
    for (const key of ["timer", "leadTimer", "gapTimer"]) {
      if (this[key]) {
        clearTimeout(this[key]);
        this[key] = null;
      }
    }
    if (!this.sound) return;

    if (this.watcher) {
      this.sound.removeEventListener("timeupdate", this.watcher);
      this.watcher = null;
    }
    if (this.ready) {
      this.sound.removeEventListener("canplaythrough", this.ready);
      this.ready = null;
    }
    this.sound.pause();
  }
}
