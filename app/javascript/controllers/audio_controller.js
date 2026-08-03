import { Controller } from "@hotwired/stimulus";

const LEAD_IN_MS = 140;
const STOP_GRACE_MS = 150;

export default class extends Controller {
  static values = { url: String, stopMs: Number, autoMs: Number };

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
    if (!this.urlValue) return;

    this.sound = new Audio(this.urlValue);
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

    this.sound.addEventListener("ended", () => this.halt(), { once: true });
    this.sound.play().catch(() => {});

    if (this.stopMsValue > 0) this.armStop(this.stopMsValue);
  }

  armStop(stopMs) {
    const limit = stopMs / 1000;

    this.watcher = () => {
      if (this.sound.currentTime >= limit) this.halt();
    };
    this.sound.addEventListener("timeupdate", this.watcher);

    this.timer = setTimeout(() => this.halt(), stopMs + STOP_GRACE_MS);
  }

  halt() {
    for (const key of ["timer", "leadTimer"]) {
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
