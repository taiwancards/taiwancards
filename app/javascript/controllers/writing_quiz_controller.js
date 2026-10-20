import { Controller } from "@hotwired/stimulus";
import HanziWriter from "hanzi-writer";
import { writerSize } from "lib/writer_size";

const STAGES = ["watch", "trace", "recall"];
const ACTIVE_STEP = ["border-primary", "bg-primary/10", "text-primary"];
const PASSED_STEP = ["border-emerald-500", "text-emerald-700"];

export default class extends Controller {
  static targets = [
    "square",
    "status",
    "result",
    "reveal",
    "step",
    "note",
    "watchActions",
  ];
  static values = {
    gradeUrl: String,
    advanceUrl: String,
    lexemeId: String,
    stage: { type: String, default: "recall" },
    labelGood: String,
    labelHard: String,
    labelAgain: String,
    noteWatch: String,
    noteTrace: String,
    noteRecall: String,
  };

  connect() {
    this.startedAt = performance.now();
    this.writers = [];
    this.finished = false;
    this.squareTargets.forEach((el, i) => this.build(el, i));
    this.enter(this.stageValue);
  }

  disconnect() {
    clearTimeout(this.advanceTimer);
    clearTimeout(this.stageTimer);
    this.writers.forEach((w) => w?.cancelQuiz());
  }

  build(el, i) {
    const url = el.dataset.url;
    const side = writerSize(el.parentElement, this.squareTargets.length, {
      min: 150,
      max: 240,
    });
    this.writers[i] = HanziWriter.create(el, el.dataset.char, {
      width: side,
      height: side,
      padding: 6,
      showCharacter: false,
      showOutline: false,
      strokeColor: "#18181b",
      outlineColor: "#d4d4d8",
      drawingColor: "#10b981",
      strokeAnimationSpeed: 1,
      delayBetweenStrokes: 250,
      charDataLoader: (_char, onComplete) =>
        fetch(url)
          .then((r) => r.json())
          .then(onComplete),
    });
  }

  goto(event) {
    if (this.finished) return;
    this.enter(event.currentTarget.dataset.stage);
  }

  replay() {
    if (this.stage !== "watch") return;

    this.run += 1;
    this.animate();
  }

  startTrace() {
    this.enter("trace");
  }

  enter(stage) {
    if (!STAGES.includes(stage)) return;
    clearTimeout(this.stageTimer);
    this.stage = stage;
    this.run = (this.run || 0) + 1;
    this.done = this.writers.map(() => false);
    this.mistakes = this.writers.map(() => 0);
    this.squareTargets.forEach((el) =>
      el.classList.remove("border-emerald-500"),
    );
    this.writers.forEach((w) => {
      w.cancelQuiz();
      w.hideCharacter();
      if (stage === "recall") w.hideOutline();
      else w.showOutline();
    });
    this.renderSteps();
    if (this.hasWatchActionsTarget)
      this.watchActionsTarget.hidden = stage !== "watch";
    if (this.hasRevealTarget) this.revealTarget.hidden = stage !== "recall";
    this.setNote(this[`note${stage[0].toUpperCase()}${stage.slice(1)}Value`]);
    this.setStatus(stage === "watch" ? "" : `0/${this.writers.length}`);
    if (stage === "watch") this.animate();
    else this.quiz(stage);
  }

  async animate() {
    const run = this.run;
    for (const writer of this.writers) {
      writer.hideCharacter();
    }
    for (const writer of this.writers) {
      if (run !== this.run) return;
      await new Promise((resolve) =>
        writer.animateCharacter({ onComplete: resolve }),
      );
    }
  }

  quiz(stage) {
    const tracing = stage === "trace";
    this.writers.forEach((writer, i) =>
      writer.quiz({
        leniency: tracing ? 1.2 : 1.0,
        showHintAfterMisses: tracing ? 1 : 3,
        onMistake: () => {
          this.mistakes[i] += 1;
        },
        onComplete: () => this.completeChar(i),
      }),
    );
  }

  completeChar(i) {
    this.done[i] = true;
    this.squareTargets[i].classList.add("border-emerald-500");
    const finished = this.done.filter(Boolean).length;
    this.setStatus(`${finished}/${this.writers.length}`);
    if (finished < this.writers.length) return;
    if (this.stage === "trace") {
      this.stageTimer = setTimeout(() => this.enter("recall"), 700);
    } else if (this.stage === "recall" && !this.finished) {
      this.finish();
    }
  }

  finish() {
    this.finished = true;
    const clean = this.mistakes.every((count) => count === 0);
    this.grade(clean ? "good" : "hard");
    this.showResult(clean ? this.labelGoodValue : this.labelHardValue, clean);
    this.advanceTimer = setTimeout(() => this.advance(), 1200);
  }

  reveal() {
    if (this.finished) return;
    this.finished = true;
    this.writers.forEach((w) => {
      w.cancelQuiz();
      w.showOutline();
      w.animateCharacter();
    });
    this.grade("again");
    this.showResult(this.labelAgainValue, false);
    if (this.hasRevealTarget) this.revealTarget.disabled = true;
  }

  async grade(rating) {
    const body = new URLSearchParams({
      lexeme_id: this.lexemeIdValue,
      rating,
      elapsed_ms: Math.round(performance.now() - this.startedAt),
    });
    try {
      await fetch(this.gradeUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": this.csrf(),
        },
        body,
      });
    } catch {}
  }

  advance() {
    if (this.advanceUrlValue) window.location.href = this.advanceUrlValue;
  }

  renderSteps() {
    const current = STAGES.indexOf(this.stage);
    this.stepTargets.forEach((step) => {
      const index = STAGES.indexOf(step.dataset.stage);
      step.classList.remove(...ACTIVE_STEP, ...PASSED_STEP);
      if (index === current) step.classList.add(...ACTIVE_STEP);
      else if (index < current) step.classList.add(...PASSED_STEP);
      step.setAttribute("aria-current", index === current ? "step" : "false");
    });
  }

  showResult(text, ok) {
    if (!this.hasResultTarget) return;
    this.resultTarget.textContent = text;
    this.resultTarget.classList.toggle("text-emerald-600", ok);
    this.resultTarget.classList.toggle("text-amber-600", !ok);
  }

  setNote(text) {
    if (this.hasNoteTarget) this.noteTarget.textContent = text || "";
  }

  setStatus(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text;
  }

  csrf() {
    return document.querySelector('meta[name="csrf-token"]')?.content;
  }
}
