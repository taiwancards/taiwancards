import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["display", "form"];
  static values = { seconds: Number };

  connect() {
    this.remaining = this.secondsValue;
    this.render();
    this.timer = setInterval(() => this.tick(), 1000);
  }

  disconnect() {
    clearInterval(this.timer);
  }

  tick() {
    this.remaining -= 1;
    if (this.remaining <= 0) {
      clearInterval(this.timer);
      this.remaining = 0;
      this.render();
      if (this.hasFormTarget) this.formTarget.requestSubmit();
      return;
    }
    this.render();
  }

  render() {
    const minutes = Math.floor(this.remaining / 60);
    const seconds = this.remaining % 60;
    this.displayTarget.textContent = `${minutes}:${String(seconds).padStart(2, "0")}`;
    if (this.remaining <= 60) this.displayTarget.classList.add("text-red-500");
  }
}
