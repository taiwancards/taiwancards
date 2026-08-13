import { Controller } from "@hotwired/stimulus";

const YEAR = 60 * 60 * 24 * 365;
const MODES = ["off", "zhuyin", "pinyin"];

export default class extends Controller {
  connect() {
    this.reflect();
  }

  cycle() {
    const next = MODES[(MODES.indexOf(this.mode()) + 1) % MODES.length];
    const root = document.documentElement.classList;

    root.toggle("no-zhuyin", next === "off");
    root.toggle("no-pinyin", next !== "pinyin");
    document.cookie = `readings=${next}; path=/; max-age=${YEAR}; samesite=lax`;
    document
      .querySelectorAll('[data-controller~="readings"]')
      .forEach((element) =>
        element.dispatchEvent(new CustomEvent("readings:reflect")),
      );
  }

  reflect() {
    this.element.setAttribute("aria-pressed", String(this.mode() !== "off"));
    this.element.dataset.readingsMode = this.mode();
  }

  mode() {
    const root = document.documentElement.classList;
    if (root.contains("no-zhuyin")) return "off";

    return root.contains("no-pinyin") ? "zhuyin" : "pinyin";
  }
}
