import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.element.style.transition = "opacity 300ms ease, transform 300ms ease";
    this.fadeTimer = setTimeout(() => {
      this.element.style.opacity = "0";
      this.element.style.transform = "translateY(-8px)";
      this.removeTimer = setTimeout(() => this.element.remove(), 350);
    }, 2500);
  }

  disconnect() {
    clearTimeout(this.fadeTimer);
    clearTimeout(this.removeTimer);
  }
}
