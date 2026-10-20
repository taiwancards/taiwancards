import { Controller } from "@hotwired/stimulus";

const RIGHT = ["border-emerald-500", "bg-emerald-500/10"];
const WRONG = ["border-amber-500", "bg-amber-500/10"];
const IDLE = ["border-border", "bg-card", "hover:bg-muted"];
const PAUSE_MS = 600;

export default class extends Controller {
  static targets = [
    "step",
    "choice",
    "explanation",
    "reply",
    "next",
    "summary",
    "result",
  ];
  static values = { score: String };

  connect() {
    this.position = 0;
    this.firstTry = 0;
    this.questions = this.stepTargets.filter(
      (step) => step.dataset.choice === "true",
    ).length;
    this.flow();
  }

  disconnect() {
    clearTimeout(this.timer);
  }

  flow() {
    const step = this.stepTargets[this.position];
    if (!step) return this.finish();
    this.show(step);
    if (step.dataset.choice !== "true") {
      this.position += 1;
      this.timer = setTimeout(() => this.flow(), PAUSE_MS);
    }
  }

  choose(event) {
    const button = event.currentTarget;
    const step = button.closest("[data-dialogue-target='step']");
    const choices = this.within(step, this.choiceTargets);
    const correct = button.dataset.correct === "true";
    choices.forEach((choice) => {
      choice.disabled = true;
      if (choice.dataset.correct === "true") this.paint(choice, RIGHT);
    });
    if (!correct) this.paint(button, WRONG);
    if (correct) this.firstTry += 1;

    const shown = this.within(step, this.explanationTargets).filter(
      (note) =>
        note.dataset.slot === button.dataset.slot ||
        (!correct &&
          choices[Number(note.dataset.slot)]?.dataset.correct === "true"),
    );
    shown.forEach((note) => (note.hidden = false));
    this.within(step, this.replyTargets).forEach(
      (reply) => (reply.hidden = false),
    );

    this.position += 1;
    if (correct && shown.length === 0) {
      this.timer = setTimeout(() => this.flow(), PAUSE_MS);
    } else {
      this.within(step, this.nextTargets).forEach((next) => {
        next.hidden = false;
        next.querySelector("button")?.focus({ preventScroll: true });
      });
    }
  }

  next(event) {
    event.currentTarget.closest("[data-dialogue-target='next']").hidden = true;
    this.flow();
  }

  finish() {
    if (!this.hasSummaryTarget) return;
    this.resultTarget.textContent = this.scoreValue
      .replace("%{right}", String(this.firstTry))
      .replace("%{total}", String(this.questions));
    this.show(this.summaryTarget);
  }

  paint(element, classes) {
    element.classList.remove(...IDLE);
    element.classList.add(...classes);
  }

  show(element) {
    element.hidden = false;
    element.scrollIntoView({ behavior: "smooth", block: "nearest" });
  }

  within(step, targets) {
    return targets.filter((target) => step.contains(target));
  }
}
