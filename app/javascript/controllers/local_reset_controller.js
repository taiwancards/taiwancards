import { Controller } from "@hotwired/stimulus";

const KEYS = [
  "hints.zhuyin",
  "hints.pinyin",
  "desktop-hint.seen",
  "pron_prelisten",
  "graded.translations",
];

export default class extends Controller {
  connect() {
    KEYS.forEach((key) => localStorage.removeItem(key));
    this.element.remove();
  }
}
