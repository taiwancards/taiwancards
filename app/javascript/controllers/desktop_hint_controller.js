import { Controller } from "@hotwired/stimulus";

const KEY = "desktop-hint.seen";
const PHONE = "(max-width: 767px)";

export default class extends Controller {
  connect() {
    if (localStorage.getItem(KEY) === "1") return;
    if (!window.matchMedia(PHONE).matches) return;

    this.element.classList.remove("hidden");
  }

  dismiss() {
    localStorage.setItem(KEY, "1");
    this.element.remove();
  }
}
