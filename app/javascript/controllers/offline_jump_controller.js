import { Controller } from "@hotwired/stimulus";

const DELAY = 300;

export default class extends Controller {
  static values = { url: String, delay: { type: Number, default: DELAY } };

  connect() {
    this.timer = null;
  }

  disconnect() {
    clearTimeout(this.timer);
  }

  jump(event) {
    const asked = event.target.value.trim();
    clearTimeout(this.timer);
    if (asked === "") return;

    const target = `${this.urlValue}?q=${encodeURIComponent(asked)}`;
    this.timer = setTimeout(() => window.Turbo.visit(target), this.delayValue);
  }
}
