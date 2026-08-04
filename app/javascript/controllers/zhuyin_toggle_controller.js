import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["button"];
  static values = { on: Boolean };

  connect() {
    this.render();
  }

  toggle() {
    this.onValue = !this.onValue;
    this.render();
  }

  render() {
    this.element.classList.toggle("no-zhuyin", !this.onValue);
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-pressed", String(this.onValue));
      this.buttonTarget.classList.toggle("bg-primary/10", this.onValue);
      this.buttonTarget.classList.toggle("border-primary", this.onValue);
    }
  }
}
