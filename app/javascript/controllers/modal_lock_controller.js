import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.locked = [...document.body.children].filter(
      (element) =>
        element !== this.element &&
        !element.contains(this.element) &&
        !element.inert,
    );
    this.locked.forEach((element) => {
      element.inert = true;
    });
    document.documentElement.classList.add("overflow-hidden");
    this.element.querySelector("input, button")?.focus({ preventScroll: true });
  }

  disconnect() {
    this.locked?.forEach((element) => {
      element.inert = false;
    });
    document.documentElement.classList.remove("overflow-hidden");
  }
}
