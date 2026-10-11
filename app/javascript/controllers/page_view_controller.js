import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { url: String };

  connect() {
    if (!this.urlValue || !navigator.sendBeacon) return;

    const payload = JSON.stringify({
      path: window.location.pathname,
      referrer: document.referrer,
    });
    navigator.sendBeacon(
      this.urlValue,
      new Blob([payload], { type: "text/plain" }),
    );
  }
}
