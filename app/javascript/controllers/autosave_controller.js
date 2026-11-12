import { Controller } from "@hotwired/stimulus";
import { csrfToken } from "lib/csrf";

export default class extends Controller {
  static targets = ["status"];

  connect() {
    this.timer = null;
  }

  disconnect() {
    if (this.timer) clearTimeout(this.timer);
    if (this.hideTimer) clearTimeout(this.hideTimer);
  }

  save() {
    if (this.timer) clearTimeout(this.timer);
    this.timer = setTimeout(() => this.submit(), 250);
  }

  async submit() {
    const form =
      this.element.closest("form") || this.element.querySelector("form");
    if (!form) return;

    const body = new FormData(form);
    body.append("inline", "1");

    try {
      const response = await fetch(form.action, {
        method: "POST",
        headers: { "X-CSRF-Token": csrfToken(), Accept: "application/json" },
        body,
      });
      this.flash(response.ok);
    } catch {
      this.flash(false);
    }
  }

  flash(ok) {
    if (!this.hasStatusTarget) return;

    const node = this.statusTarget;
    node.textContent = ok ? node.dataset.saved : node.dataset.failed;
    node.dataset.state = ok ? "ok" : "bad";
    node.dataset.visible = "true";

    if (this.hideTimer) clearTimeout(this.hideTimer);
    this.hideTimer = setTimeout(() => {
      node.dataset.visible = "false";
    }, 1800);
  }
}
