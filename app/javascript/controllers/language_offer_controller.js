import { Controller } from "@hotwired/stimulus";

const SEEN = "language_offer_seen";

export default class extends Controller {
  connect() {
    this.element.hidden =
      /(^|;\s*)locale=/.test(document.cookie) || this.seen();
    this.markSeen();
  }

  dismiss() {
    this.element.hidden = true;
  }

  seen() {
    try {
      return sessionStorage.getItem(SEEN) === "1";
    } catch {
      return false;
    }
  }

  markSeen() {
    try {
      sessionStorage.setItem(SEEN, "1");
    } catch {}
  }
}
