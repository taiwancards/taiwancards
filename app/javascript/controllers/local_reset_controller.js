import { Controller } from "@hotwired/stimulus";

const KEYS = [
  "hints.zhuyin",
  "hints.pinyin",
  "pron_prelisten",
  "graded.translations",
  "cangjie.progress",
];

const PREFIXES = ["layers."];

export default class extends Controller {
  connect() {
    try {
      KEYS.forEach((key) => localStorage.removeItem(key));
      Object.keys(localStorage)
        .filter((key) => PREFIXES.some((prefix) => key.startsWith(prefix)))
        .forEach((key) => localStorage.removeItem(key));
    } catch {}
    this.element.remove();
  }
}
