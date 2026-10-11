import { Controller } from "@hotwired/stimulus";

const ADVANCE_MS = 160;

export default class extends Controller {
  static targets = [
    "goal",
    "step",
    "level",
    "variant",
    "detail",
    "known",
    "plain",
    "counter",
    "next",
  ];
  static values = { optional: Array, ask: Boolean };

  connect() {
    this.show("goal");
    this.sync();
  }

  disconnect() {
    clearTimeout(this.timer);
  }

  pick(event) {
    this.sync();
    if (!this.askValue || event.detail === 0) return;

    clearTimeout(this.timer);
    this.timer = setTimeout(() => this.forward(), ADVANCE_MS);
  }

  forward() {
    if (this.goal) this.show("level");
  }

  back() {
    this.show("goal");
  }

  show(name) {
    this.stepTargets.forEach((step) => {
      step.hidden = step.dataset.step !== name;
    });
    if (this.hasCounterTarget) {
      const index = this.stepTargets.findIndex(
        (step) => step.dataset.step === name,
      );
      this.counterTarget.textContent = this.counterTarget.dataset.template
        .replace("%{step}", index + 1)
        .replace("%{total}", this.stepTargets.length);
    }
    const current = this.stepTargets.find((step) => step.dataset.step === name);
    current
      ?.querySelector("input:checked, input")
      ?.focus({ preventScroll: true });
  }

  sync() {
    const goal = this.goal;
    const optional = this.optionalValue.includes(goal);
    if (this.hasNextTarget) this.nextTarget.disabled = !goal;

    this.variantTargets.forEach((node) => {
      node.hidden = node.dataset.goal !== goal;
    });

    const level = this.levelTargets.find((input) => input.checked)?.value;
    this.detailTargets.forEach((node) => {
      node.hidden = node.dataset.level !== level;
    });
    if (this.hasKnownTarget) this.knownTarget.hidden = optional;
    if (this.hasPlainTarget) this.plainTarget.hidden = !optional;
  }

  get goal() {
    return this.goalTargets.find((input) => input.checked)?.value;
  }
}
