import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["line", "button"];

  connect() {
    this.shown = false;
  }

  toggle() {
    this.shown = !this.shown;
    this.lineTargets.forEach((line) =>
      line.classList.toggle("hidden", !this.shown),
    );
    if (this.hasButtonTarget) {
      const button = this.buttonTarget;
      button.textContent = this.shown
        ? button.dataset.hideLabel
        : button.dataset.showLabel;
    }
  }
}
