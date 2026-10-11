import { Controller } from "@hotwired/stimulus";

const ADVANCE_MS = 650;
const RIGHT = ["border-emerald-500", "bg-emerald-50", "text-emerald-700"];
const WRONG = ["border-red-500", "text-red-600"];

export default class extends Controller {
  static targets = ["step", "bar", "symbols", "words"];
  static values = { right: String, wrong: String };

  connect() {
    this.results = { symbols: {}, words: {} };
    this.index = -1;
    this.next();
  }

  disconnect() {
    if (this.timer) clearTimeout(this.timer);
  }

  next() {
    if (this.timer) clearTimeout(this.timer);
    this.current?.setAttribute("hidden", "");
    this.index = Math.min(this.index + 1, this.stepTargets.length - 1);
    this.current.hidden = false;

    const last = Math.max(this.stepTargets.length - 1, 1);
    this.barTarget.style.width = `${Math.round((this.index / last) * 100)}%`;
    window.scrollTo({ top: 0, behavior: "smooth" });
    this.listen();
  }

  answer(event) {
    const button = event.currentTarget;
    const step = this.current;
    if (step.dataset.solved) return;

    const { group, subject } = button.dataset;
    const correct = button.dataset.correct === "true";
    if (!(subject in this.results[group]))
      this.results[group][subject] = correct;
    this.store();

    const feedback = step.querySelector("[data-feedback]");
    if (correct) {
      step.dataset.solved = "true";
      button.classList.add(...RIGHT);
      if (feedback) feedback.textContent = this.rightValue;
      this.timer = setTimeout(() => this.next(), ADVANCE_MS);
    } else {
      button.classList.add(...WRONG);
      button.disabled = true;
      if (feedback) feedback.textContent = this.wrongValue;
      this.listen();
    }
  }

  listen() {
    this.current.querySelector("[data-controller~='audio']")?.click();
  }

  store() {
    this.symbolsTarget.value = JSON.stringify(this.results.symbols);
    this.wordsTarget.value = JSON.stringify(this.results.words);
  }

  get current() {
    return this.stepTargets[this.index];
  }
}
