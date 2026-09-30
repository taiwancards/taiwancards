import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { current: String, url: String };

  connect() {
    const zone = Intl.DateTimeFormat().resolvedOptions().timeZone;
    if (!zone || zone === this.currentValue) return;

    this.currentValue = zone;
    fetch(this.urlValue, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")
          ?.content,
      },
      body: JSON.stringify({ zone }),
    });
  }
}
