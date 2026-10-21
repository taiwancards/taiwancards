import { Controller } from "@hotwired/stimulus";

const TONES = { 6: "ˊ", 3: "ˇ", 4: "ˋ", 7: "˙" };

export default class extends Controller {
  static targets = [
    "player",
    "clip",
    "last",
    "answer",
    "form",
    "check",
    "next",
    "result",
    "translation",
    "progress",
    "size",
    "summary",
    "average",
    "keyboard",
    "keyboardToggle",
    "key",
  ];
  static values = { items: Array, keys: Object };

  connect() {
    this.index = 0;
    this.scores = [];
    this.zhuyin = false;
    if (this.itemsValue.length) this.show();
  }

  get item() {
    return this.itemsValue[this.index];
  }

  get finalItem() {
    return this.index === this.itemsValue.length - 1;
  }

  show() {
    const item = this.item;
    this.checked = false;
    this.playerTarget.dataset.audioUrlValue = item.url;
    this.clipTarget.value = item.clip;
    this.lastTarget.value = this.finalItem ? "1" : "";
    this.answerTarget.value = "";
    this.answerTarget.readOnly = false;
    this.resultTarget.replaceChildren();
    this.translationTarget.textContent = item.translation || "";
    this.translationTarget.hidden = true;
    this.sizeTarget.textContent = item.hint || "";
    this.progressTarget.textContent = `${this.index + 1} / ${this.itemsValue.length}`;
    this.nextTarget.hidden = true;
    this.checkTarget.hidden = false;
  }

  guard(event) {
    if (this.checked) event.preventDefault();
  }

  scoreTargetConnected(element) {
    this.checked = true;
    this.scores[this.index] = Number(element.dataset.percent) || 0;
    this.answerTarget.readOnly = true;
    this.checkTarget.hidden = true;
    this.translationTarget.hidden = true;

    if (this.finalItem) return this.finish();

    this.nextTarget.hidden = false;
    this.nextTarget.focus({ preventScroll: true });
  }

  next() {
    this.index += 1;
    this.show();
    this.playerTarget.click();
    if (!this.zhuyin) this.answerTarget.focus({ preventScroll: true });
  }

  finish() {
    const total = this.scores.reduce((sum, score) => sum + score, 0);
    this.averageTarget.textContent = `${Math.round(total / this.scores.length)}%`;
    this.summaryTarget.hidden = false;
  }

  hint() {
    this.translationTarget.hidden = false;
  }

  toggleKeyboard() {
    this.zhuyin = !this.zhuyin;
    this.keyboardTarget.hidden = !this.zhuyin;
    this.answerTarget.inputMode = this.zhuyin ? "none" : "text";
    this.keyboardToggleTarget.setAttribute("aria-pressed", String(this.zhuyin));
    this.keyboardToggleTarget.classList.toggle("bg-muted", this.zhuyin);
    this.answerTarget.focus({ preventScroll: true });
  }

  type(event) {
    if (!this.zhuyin || event.isComposing) return;
    if (event.metaKey || event.ctrlKey || event.altKey) return;

    const key = event.key.toLowerCase();
    const symbol = this.keysValue[key] || TONES[key];
    if (symbol === undefined) return;

    event.preventDefault();
    this.insert(symbol);
    this.flash(key);
  }

  tap(event) {
    const key = event.currentTarget.dataset.key;
    if (this.answerTarget.readOnly) return;
    if (key === "Enter") return this.formTarget.requestSubmit();
    if (key === "Backspace") return this.erase();

    const symbol = key === " " ? " " : this.keysValue[key] || TONES[key];
    if (symbol === undefined) return;

    this.insert(symbol);
    this.flash(key);
  }

  insert(text) {
    const input = this.answerTarget;
    const start = input.selectionStart ?? input.value.length;
    const end = input.selectionEnd ?? start;
    input.setRangeText(text, start, end, "end");
  }

  erase() {
    const input = this.answerTarget;
    const start = input.selectionStart ?? input.value.length;
    const end = input.selectionEnd ?? start;
    if (start === end && start > 0)
      input.setRangeText("", start - 1, end, "end");
    else input.setRangeText("", start, end, "end");
  }

  flash(key) {
    const node = this.keyTargets.find(
      (candidate) => candidate.dataset.key === key,
    );
    if (!node) return;
    node.dataset.hit = "true";
    setTimeout(() => {
      node.dataset.hit = "false";
    }, 140);
  }
}
