import { Controller } from "@hotwired/stimulus";
import { csrfToken } from "lib/csrf";

export default class extends Controller {
  static values = { current: String, url: String };

  connect() {
    const zone = Intl.DateTimeFormat().resolvedOptions().timeZone;
    if (!zone || zone === this.currentValue) return;

    const previous = this.currentValue;
    this.currentValue = zone;
    fetch(this.urlValue, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken(),
      },
      body: JSON.stringify({ zone }),
    })
      .then((response) => {
        if (!response.ok) this.currentValue = previous;
      })
      .catch(() => {
        this.currentValue = previous;
      });
  }
}
