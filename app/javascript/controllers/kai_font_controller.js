import { Controller } from "@hotwired/stimulus";

let pending = null;

export default class extends Controller {
  static values = { url: String };

  connect() {
    if (document.documentElement.classList.contains("font-kai")) {
      this.warm();
    } else {
      this.onToggle = () => this.warm();
      document.addEventListener("display-pref:changed", this.onToggle);
    }
  }

  disconnect() {
    if (this.onToggle)
      document.removeEventListener("display-pref:changed", this.onToggle);
  }

  warm() {
    if (pending || !this.urlValue || !window.FontFace) return;

    const start = () => {
      const face = new FontFace(
        "TW Kai",
        `url(${this.urlValue}) format("woff2")`,
        {
          style: "normal",
          weight: "400",
          display: "swap",
        },
      );

      pending = face
        .load()
        .then((loaded) => document.fonts.add(loaded))
        .catch(() => {
          pending = null;
        });
    };

    if (document.readyState === "complete") {
      this.whenIdle(start);
    } else {
      window.addEventListener("load", () => this.whenIdle(start), {
        once: true,
      });
    }
  }

  whenIdle(callback) {
    if (window.requestIdleCallback) {
      window.requestIdleCallback(callback, { timeout: 3000 });
    } else {
      setTimeout(callback, 1200);
    }
  }
}
