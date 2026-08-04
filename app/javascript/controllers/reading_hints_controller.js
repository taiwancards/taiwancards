import { Controller } from "@hotwired/stimulus";

const ZHUYIN_KEY = "hints.zhuyin";
const PINYIN_KEY = "hints.pinyin";

export default class extends Controller {
  static targets = ["zhuyin", "pinyin"];

  connect() {
    this.zhuyin = localStorage.getItem(ZHUYIN_KEY) !== "0";
    this.pinyin = this.zhuyin && localStorage.getItem(PINYIN_KEY) === "1";
    this.render();
  }

  toggleZhuyin() {
    this.zhuyin = !this.zhuyin;
    if (!this.zhuyin) this.pinyin = false;
    this.store();
    this.render();
  }

  togglePinyin() {
    this.pinyin = !this.pinyin;
    if (this.pinyin) this.zhuyin = true;
    this.store();
    this.render();
  }

  store() {
    localStorage.setItem(ZHUYIN_KEY, this.zhuyin ? "1" : "0");
    localStorage.setItem(PINYIN_KEY, this.pinyin ? "1" : "0");
  }

  render() {
    this.element.classList.toggle("hints-zhuyin", this.zhuyin);
    this.element.classList.toggle("hints-pinyin", this.pinyin);
    this.mark(this.zhuyinTargets, this.zhuyin);
    this.mark(this.pinyinTargets, this.pinyin);
  }

  mark(buttons, on) {
    buttons.forEach((button) => {
      button.setAttribute("aria-pressed", String(on));
      button.classList.toggle("border-primary", on);
      button.classList.toggle("text-primary", on);
      button.classList.toggle("bg-primary/10", on);
      button.classList.toggle("text-muted-foreground", !on);
    });
  }
}
