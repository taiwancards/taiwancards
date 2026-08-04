import { Controller } from "@hotwired/stimulus";

const DIRECTIONS = ["up", "right", "down", "left"];

export default class extends Controller {
  static targets = [
    "card",
    "prompt",
    "note",
    "option",
    "feedback",
    "counter",
    "board",
    "summary",
    "correct",
    "total",
  ];
  static values = { items: Array, url: String, resultUrl: String };

  connect() {
    this.keyHandler = (event) => this.onKey(event);
    document.addEventListener("keydown", this.keyHandler);
    this.begin();
  }

  disconnect() {
    document.removeEventListener("keydown", this.keyHandler);
    clearTimeout(this.timer);
  }

  begin() {
    clearTimeout(this.timer);
    this.queue = [...this.itemsValue];
    this.planned = this.queue.length;
    this.done = 0;
    this.correct = 0;
    this.reported = false;
    this.summaryTarget.classList.add("hidden");
    this.boardTarget.classList.remove("hidden");
    this.next();
  }

  next() {
    clearTimeout(this.timer);
    if (this.queue.length === 0) return this.finish();

    this.current = this.queue[0];
    this.answered = false;
    this.feedbackTarget.textContent = "";
    this.feedbackTarget.className = "mt-3 h-6 text-center text-sm font-medium";

    this.promptTarget.textContent = this.current.prompt;
    this.promptTarget.lang = this.current.prompt_lang || "en";
    this.noteTarget.textContent = "";

    const options = this.shuffle([
      { value: this.current.answer, correct: true },
      ...this.current.distractors.map((value) => ({ value, correct: false })),
    ]);

    this.optionTargets.forEach((node, index) => {
      const option = options[index];
      node.dataset.correct = String(Boolean(option && option.correct));
      node.lang = this.current.answer_lang || "en";
      node.querySelector("[data-label]").textContent = option
        ? option.value
        : "";
      node.className = this.optionClass();
    });

    this.counterTarget.textContent = `${this.done} / ${this.planned}`;
  }

  optionClass() {
    return "flex min-h-16 w-full items-center justify-center rounded-2xl border border-border bg-background px-3 py-3 text-center text-lg font-semibold transition-colors";
  }

  shuffle(list) {
    return list
      .map((value) => ({ value, key: Math.random() }))
      .sort((a, b) => a.key - b.key)
      .map((entry) => entry.value);
  }

  onKey(event) {
    const map = {
      ArrowUp: "up",
      ArrowRight: "right",
      ArrowDown: "down",
      ArrowLeft: "left",
    };
    if (!map[event.key]) return;
    event.preventDefault();
    this.answer(map[event.key]);
  }

  choose(event) {
    this.answer(event.currentTarget.dataset.direction);
  }

  answer(direction) {
    if (this.answered || !this.current) return;
    this.answered = true;

    const chosen = this.optionTargets.find(
      (node) => node.dataset.direction === direction,
    );
    const right = this.optionTargets.find(
      (node) => node.dataset.correct === "true",
    );
    const good = chosen && chosen.dataset.correct === "true";

    if (chosen && !good)
      chosen.className = `${this.optionClass()} border-red-500 bg-red-500/10`;
    if (right)
      right.className = `${this.optionClass()} border-emerald-500 bg-emerald-500/10`;

    if (good) {
      this.correct += 1;
      this.done += 1;
      this.queue.shift();
      this.feedbackTarget.classList.add("text-emerald-600");
      this.feedbackTarget.textContent = "✓";
    } else {
      const missed = this.queue.shift();
      this.queue.push(missed);
      this.feedbackTarget.classList.add("text-red-500");
      this.feedbackTarget.textContent = this.current.answer;
    }

    if (this.current.note) this.noteTarget.textContent = this.current.note;

    this.timer = setTimeout(() => this.next(), good ? 700 : 2000);
  }

  finish() {
    this.current = null;
    this.boardTarget.classList.add("hidden");
    this.summaryTarget.classList.remove("hidden");
    this.correctTarget.textContent = this.correct;
    this.totalTarget.textContent = this.planned;
    this.report();
  }

  report() {
    if (this.reported || !this.resultUrlValue) return;
    const token = document.querySelector("meta[name='csrf-token']")?.content;
    if (!token) return;

    this.reported = true;
    fetch(this.resultUrlValue, {
      method: "POST",
      headers: { "X-CSRF-Token": token },
    }).catch(() => {});
  }
}
