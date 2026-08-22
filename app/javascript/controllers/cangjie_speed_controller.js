import { Controller } from "@hotwired/stimulus";
import { load, pace, recordChar, recordRun } from "lib/cangjie_progress";

const ROUND = 20;

export default class extends Controller {
  static targets = [
    "prompt",
    "typed",
    "tally",
    "feedback",
    "pad",
    "stats",
    "start",
    "check",
    "mode",
    "resume",
  ];
  static values = { core: Array, exam: Array, labels: Object };

  connect() {
    this.mode = "core";
    this.running = false;
    this.paintModes();
    this.paintStats();
  }

  label(key) {
    return this.labelsValue[key] || "";
  }

  pick(event) {
    if (this.running) return;
    this.mode = event.currentTarget.dataset.mode;
    this.paintModes();
  }

  paintModes() {
    this.modeTargets.forEach((button) => {
      const active = button.dataset.mode === this.mode;
      button.classList.toggle("border-brand", active);
      button.classList.toggle("bg-brand/10", active);
    });
  }

  pool() {
    return this.mode === "exam" ? this.examValue : this.coreValue;
  }

  start() {
    const seen = load().chars;
    this.round = this.pool()
      .map((row, order) => ({ ...row, order }))
      .sort(
        (a, b) =>
          (seen[a.char]?.right || 0) - (seen[b.char]?.right || 0) ||
          a.order - b.order,
      )
      .slice(0, ROUND);
    for (let i = this.round.length - 1; i > 0; i -= 1) {
      const j = Math.floor(Math.random() * (i + 1));
      [this.round[i], this.round[j]] = [this.round[j], this.round[i]];
    }
    this.index = 0;
    this.right = 0;
    this.spent = 0;
    this.running = true;
    this.padTarget.hidden = false;
    this.statsTarget.hidden = true;
    this.startTarget.hidden = true;
    this.render();
  }

  get task() {
    return this.round[this.index];
  }

  render() {
    if (this.index >= this.round.length) return this.finish();

    this.settled = false;
    this.buffer = "";
    this.startedAt = performance.now();
    this.promptTarget.textContent = this.task.char;
    this.feedbackTarget.textContent = "";
    this.feedbackTarget.className = "min-h-5 text-center text-sm";
    this.resumeTarget.hidden = true;
    this.checkTarget.disabled = false;
    this.tallyTarget.textContent = `${this.index + 1} / ${this.round.length} · ${this.right}`;
    this.paint();
  }

  press(event) {
    this.type(event.currentTarget.dataset.key);
  }

  type(letter) {
    if (!this.running || this.settled || this.buffer.length >= 5) return;
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
    if (!this.running || this.settled || !this.buffer) return;
    const elapsed = performance.now() - this.startedAt;
    const correct = this.buffer === this.task.code;
    this.settled = true;
    this.spent += elapsed;
    this.checkTarget.disabled = true;
    recordChar(this.task.char, correct, correct ? elapsed : null);

    if (correct) {
      this.right += 1;
      this.next();
      return;
    }

    this.feedbackTarget.textContent = `${this.label("wrong")} ${this.task.code.toUpperCase()}`;
    this.feedbackTarget.className = "min-h-5 text-center text-sm text-red-500";
    this.resumeTarget.hidden = false;
    this.resumeTarget.focus({ preventScroll: true });
  }

  next() {
    if (!this.settled) return;
    this.index += 1;
    this.render();
  }

  finish() {
    this.running = false;
    recordRun("speed", this.right, this.round.length, this.spent);
    this.feedbackTarget.textContent = "";
    this.resumeTarget.hidden = true;
    this.promptTarget.textContent = `${this.right} / ${this.round.length}`;
    this.tallyTarget.textContent = this.label("done");
    this.padTarget.hidden = true;
    this.startTarget.textContent = this.label("again");
    this.startTarget.hidden = false;
    this.paintStats();
  }

  paintStats() {
    const rates = pace();
    if (!rates) return;

    const cells = [
      [
        this.label("pace"),
        `${Math.round(rates.current)} ${this.label("pace_unit")}`,
      ],
      [this.label("rounds"), rates.runs],
    ];
    if (rates.earlier > 0) {
      const delta = Math.round(
        ((rates.current - rates.earlier) / rates.earlier) * 100,
      );
      cells.push([this.label("delta"), `${delta > 0 ? "+" : ""}${delta}%`]);
    }

    this.statsTarget.replaceChildren(
      ...cells.map(([title, value]) => {
        const cell = document.createElement("div");
        cell.className = "rounded-xl border border-border px-3 py-2";
        const heading = document.createElement("div");
        heading.className = "text-xs text-muted-foreground";
        heading.textContent = title;
        const body = document.createElement("div");
        body.className = "text-lg font-semibold tabular-nums";
        body.textContent = value;
        cell.append(heading, body);
        return cell;
      }),
    );
    this.statsTarget.hidden = false;
  }

  keydown(event) {
    if (!this.running) return;
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
  }
}
