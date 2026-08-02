import { Controller } from "@hotwired/stimulus";
import HanziWriter from "hanzi-writer";
import { writerSize } from "lib/writer_size";

const SETTLE_MS = 900;

export default class extends Controller {
  static targets = [
    "square",
    "status",
    "result",
    "rating",
    "elapsed",
    "form",
    "hint",
    "skip",
  ];
  static values = {
    labelCorrect: String,
    labelHinted: String,
    labelSkipped: String,
  };

  connect() {
    this.startedAt = performance.now();
    this.writers = [];
    this.done = [];
    this.mistakes = [];
    this.hinted = false;
    this.finished = false;
    this.squareTargets.forEach((element, index) => this.build(element, index));
    this.report();
  }

  disconnect() {
    if (this.timer) clearTimeout(this.timer);
    this.writers.forEach((writer) => writer?.cancelQuiz());
  }

  build(element, index) {
    this.done[index] = false;
    this.mistakes[index] = 0;

    const side = writerSize(element.parentElement, this.squareTargets.length, {
      min: 140,
      max: 220,
    });
    const writer = HanziWriter.create(element, element.dataset.char, {
      width: side,
      height: side,
      padding: 6,
      showCharacter: false,
      showOutline: false,
      showHintAfterMisses: false,
      strokeColor: "#18181b",
      drawingColor: "#10b981",
      charDataLoader: (_char, onComplete) =>
        fetch(element.dataset.url)
          .then((response) => response.json())
          .then(onComplete),
    });

    this.writers[index] = writer;
    writer.quiz({
      leniency: 1.0,
      showHintAfterMisses: false,
      onMistake: () => {
        this.mistakes[index] += 1;
      },
      onComplete: () => this.complete(index, element),
    });
  }

  complete(index, element) {
    this.done[index] = true;
    element.classList.add("border-emerald-500");
    this.report();
    if (this.done.every(Boolean))
      this.settle(this.verdict(), this.labelFor(this.verdict()));
  }

  verdict() {
    if (this.hinted) return "hard";
    return this.mistakes.reduce((total, count) => total + count, 0) === 0
      ? "good"
      : "hard";
  }

  labelFor(rating) {
    return rating === "good" ? this.labelCorrectValue : this.labelHintedValue;
  }

  hint() {
    if (this.finished) return;

    this.hinted = true;
    this.writers.forEach((writer, index) => {
      if (!this.done[index]) writer?.showOutline();
    });
    if (this.hasHintTarget) this.hintTarget.disabled = true;
  }

  skip() {
    if (this.finished) return;

    this.writers.forEach((writer) => {
      writer?.cancelQuiz();
      writer?.showCharacter();
    });
    this.settle("again", this.labelSkippedValue);
  }

  settle(rating, label) {
    if (this.finished) return;

    this.finished = true;
    this.show(label, rating === "good");
    if (this.hasHintTarget) this.hintTarget.disabled = true;
    if (this.hasSkipTarget) this.skipTarget.disabled = true;
    this.timer = setTimeout(() => this.submit(rating), SETTLE_MS);
  }

  submit(rating) {
    this.ratingTarget.value = rating;
    if (this.hasElapsedTarget)
      this.elapsedTarget.value = Math.round(performance.now() - this.startedAt);
    this.formTarget.requestSubmit();
  }

  report() {
    if (!this.hasStatusTarget) return;

    this.statusTarget.textContent = `${this.done.filter(Boolean).length}/${this.squareTargets.length}`;
  }

  show(text, ok) {
    if (!this.hasResultTarget) return;

    this.resultTarget.textContent = text;
    this.resultTarget.classList.toggle("text-emerald-600", ok);
    this.resultTarget.classList.toggle("text-amber-600", !ok);
  }
}
