import { Controller } from "@hotwired/stimulus";

const KEY = "graded.translations";

export default class extends Controller {
  static targets = ["button"];

  connect() {
    this.open = localStorage.getItem(KEY) === "1";
    this.render();
  }

  toggle() {
    this.open = !this.open;
    localStorage.setItem(KEY, this.open ? "1" : "0");
    this.render();
  }

  render() {
    this.element.classList.toggle("graded-open", this.open);
    this.buttonTargets.forEach((button) => {
      button.setAttribute("aria-pressed", String(this.open));
      button.classList.toggle("border-primary", this.open);
      button.classList.toggle("text-primary", this.open);
      button.classList.toggle("text-muted-foreground", !this.open);
    });
  }
}
