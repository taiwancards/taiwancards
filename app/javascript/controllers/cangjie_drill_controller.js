import { Controller } from "@hotwired/stimulus";
import { lessonScore, recordChar, recordLesson } from "lib/cangjie_progress";

const RIGHT = ["border-emerald-500", "bg-emerald-500/10"];
const WRONG = ["border-red-500", "bg-red-500/10"];
const OPTION =
  "flex w-full items-center gap-3 rounded-lg border border-border px-3 py-2 text-left transition-colors hover:bg-muted disabled:hover:bg-transparent";

export default class extends Controller {
  static targets = [
    "kind",
    "question",
    "prompt",
    "options",
    "pad",
    "typed",
    "tally",
    "feedback",
    "next",
    "check",
    "best",
  ];
  static values = { tasks: Array, labels: Object, slug: String };

  connect() {
    this.paintBest();
    this.restart();
  }

  restart() {
    this.index = 0;
    this.score = 0;
    this.render();
  }

  get task() {
    return this.tasksValue[this.index];
  }

  label(key) {
    return this.labelsValue[key] || "";
  }

  render() {
    this.settled = false;
    this.buffer = "";
    this.feedbackTarget.textContent = "";
    this.feedbackTarget.className = "min-h-5 text-sm";
    this.nextTarget.hidden = true;

    if (this.index >= this.tasksValue.length) return this.finish();

    this.startedAt = performance.now();
    const task = this.task;
    this.tallyTarget.textContent = `${this.index + 1} / ${this.tasksValue.length} · ${this.score}`;
    this.kindTarget.textContent = this.label(task.kind);
    this.questionTarget.textContent = this.label(`${task.kind}_question`);
    this.promptTarget.textContent = task.char || task.glyph || "";
    this.promptTarget.style.transform = task.rotate
      ? `rotate(${task.rotate}deg)`
      : "";

    if (task.kind === "code") {
      this.optionsTarget.replaceChildren();
      this.optionsTarget.hidden = true;
      this.padTarget.hidden = false;
      this.checkTarget.disabled = false;
      this.paint();
    } else {
      this.padTarget.hidden = true;
      this.optionsTarget.hidden = false;
      this.buildOptions(task);
    }
  }

  buildOptions(task) {
    this.optionsTarget.replaceChildren();
    this.answers = task.options.map(
      (option) => option.char || option.letter || option.parts.join(""),
    );
    task.options.forEach((option, slot) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = OPTION;
      button.dataset.slot = slot;
      button.dataset.action = "cangjie-drill#choose";

      const badge = document.createElement("span");
      badge.className = "text-xs tabular-nums text-muted-foreground";
      badge.textContent = slot + 1;
      button.appendChild(badge);

      const body = document.createElement("span");
      body.lang = "zh-TW";
      body.className = option.char ? "text-2xl" : "text-lg";
      body.textContent = option.parts
        ? option.parts.join("")
        : option.char || option.letter;
      button.appendChild(body);

      const code = document.createElement("span");
      code.className =
        "ml-auto font-mono text-xs uppercase tracking-widest text-muted-foreground";
      code.textContent = option.key || option.code || "";
      button.appendChild(code);

      this.optionsTarget.appendChild(button);
    });
  }

  choose(event) {
    if (this.settled) return;
    const button = event.currentTarget;
    this.pick(Number(button.dataset.slot));
  }

  pick(slot) {
    if (this.settled) return;
    const buttons = Array.from(this.optionsTarget.children);
    const button = buttons[slot];
    if (!button) return;

    const correct = slot === this.task.answer;
    buttons.forEach((option, index) => {
      option.disabled = true;
      if (index === this.task.answer) option.classList.add(...RIGHT);
    });
    if (!correct) button.classList.add(...WRONG);
    this.settle(correct, this.answers[this.task.answer] || "");
  }

  press(event) {
    if (this.settled) return;
    this.type(event.currentTarget.dataset.key);
  }

  type(letter) {
    if (this.buffer.length >= 5) return;
    this.buffer += letter;
    this.paint();
    if (this.buffer.length === this.task.code.length) this.check();
  }

  erase() {
    if (this.settled) return;
    this.buffer = this.buffer.slice(0, -1);
    this.paint();
  }

  paint() {
    this.typedTarget.textContent = this.buffer.toUpperCase() || "—";
  }

  check() {
    if (this.settled || !this.buffer) return;
    const correct = this.buffer === this.task.code;
    this.checkTarget.disabled = true;
    this.settle(correct, this.task.code.toUpperCase());
  }

  settle(correct, answer) {
    this.settled = true;
    if (correct) this.score += 1;
    if (
      this.task.char &&
      (this.task.kind === "code" || this.task.kind === "split")
    ) {
      recordChar(
        this.task.char,
        correct,
        this.task.kind === "code" ? performance.now() - this.startedAt : null,
      );
    }
    this.feedbackTarget.textContent = correct
      ? this.label("right")
      : `${this.label("wrong")} ${answer}`;
    this.feedbackTarget.className = correct
      ? "min-h-5 text-sm text-emerald-600"
      : "min-h-5 text-sm text-red-500";
    this.tallyTarget.textContent = `${this.index + 1} / ${this.tasksValue.length} · ${this.score}`;
    this.nextTarget.hidden = false;
    this.nextTarget.focus({ preventScroll: true });
  }

  next() {
    this.index += 1;
    this.render();
  }

  finish() {
    if (this.slugValue && this.tasksValue.length) {
      recordLesson(this.slugValue, this.score, this.tasksValue.length);
      this.paintBest();
    }
    this.kindTarget.textContent = "";
    this.questionTarget.textContent = "";
    this.promptTarget.textContent = `${this.score} / ${this.tasksValue.length}`;
    this.promptTarget.style.transform = "";
    this.optionsTarget.replaceChildren();
    this.optionsTarget.hidden = true;
    this.padTarget.hidden = true;
    this.tallyTarget.textContent = this.label("done");
  }

  paintBest() {
    if (!this.hasBestTarget || !this.slugValue) return;
    const row = lessonScore(this.slugValue);
    this.bestTarget.textContent = row
      ? `${this.label("best")} ${row.best} / ${row.total}`
      : "";
  }

  handleKeydown(event) {
    if (event.metaKey || event.ctrlKey || event.altKey) return;
    if (event.target.closest("input, textarea, [contenteditable]")) return;
    if (!this.element.checkVisibility?.()) return;

    if (this.settled) {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        this.next();
      }
      return;
    }

    if (this.index >= this.tasksValue.length) return;

    if (this.task.kind === "code") {
      if (/^[a-zA-Z]$/.test(event.key)) {
        event.preventDefault();
        this.type(event.key.toLowerCase());
      } else if (event.key === "Backspace") {
        event.preventDefault();
        this.erase();
      } else if (event.key === "Enter") {
        event.preventDefault();
        this.check();
      }
      return;
    }

    const slot = Number(event.key) - 1;
    if (
      Number.isInteger(slot) &&
      slot >= 0 &&
      slot < this.task.options.length
    ) {
      event.preventDefault();
      this.pick(slot);
    }
  }
}
