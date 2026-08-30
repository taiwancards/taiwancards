import { Controller } from "@hotwired/stimulus";

const KEYS = [
  "hints.zhuyin",
  "hints.pinyin",
  "pron_prelisten",
  "graded.translations",
  "cangjie.progress",
];

export default class extends Controller {
  connect() {
    KEYS.forEach((key) => localStorage.removeItem(key));
    this.element.remove();
  }
}
