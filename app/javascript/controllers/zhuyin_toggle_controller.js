import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["ruby", "plain", "button"];
  static values = { on: Boolean };

  connect() {
    this.render();
  }

  toggle() {
    this.onValue = !this.onValue;
    this.render();
  }

  render() {
    this.rubyTargets.forEach((el) =>
      el.classList.toggle("hidden", !this.onValue),
    );
    this.plainTargets.forEach((el) =>
      el.classList.toggle("hidden", this.onValue),
    );
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-pressed", String(this.onValue));
      this.buttonTarget.classList.toggle("bg-primary/10", this.onValue);
      this.buttonTarget.classList.toggle("border-primary", this.onValue);
    }
  }
}
