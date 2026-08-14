import { Controller } from "@hotwired/stimulus";

const RIGHT = ["border-emerald-500", "bg-emerald-500/10"];
const WRONG = ["border-red-500", "bg-red-500/10"];

export default class extends Controller {
  static targets = ["option", "feedback", "chunk", "tray", "left", "right"];
  static values = {
    kind: String,
    answer: Number,
    rightLabel: String,
    wrongLabel: String,
  };

  connect() {
    this.settled = false;
    this.placed = [];
    this.pendingLeft = null;
    this.matched = 0;
    this.misses = 0;
  }

  choose(event) {
    if (this.settled) return;
    const button = event.currentTarget;
    const slot = Number(button.dataset.slot);
    const correct = slot === this.answerValue;
    this.optionTargets.forEach((option) => {
      option.disabled = true;
      if (Number(option.dataset.slot) === this.answerValue) {
        option.classList.add(...RIGHT);
      }
    });
    if (!correct) button.classList.add(...WRONG);
    this.settle(correct);
  }

  place(event) {
    if (this.settled) return;
    const button = event.currentTarget;
    if (button.dataset.used === "true") return;
    button.dataset.used = "true";
    button.classList.add("opacity-40");
    const slot = Number(button.dataset.slot);
    this.placed.push(slot);
    const token = document.createElement("span");
    token.className = "rounded-md bg-muted px-2 py-1 text-base font-medium";
    token.lang = "zh-TW";
    token.textContent = button.textContent.trim();
    this.trayTarget.appendChild(token);
  }

  reset() {
    if (this.settled) return;
    this.placed = [];
    this.trayTarget.replaceChildren();
    this.chunkTargets.forEach((button) => {
      button.dataset.used = "false";
      button.classList.remove("opacity-40");
    });
  }

  check() {
    if (this.settled) return;
    if (this.placed.length !== this.chunkTargets.length) return;
    const correct = this.placed.every((slot, index) => slot === index);
    this.chunkTargets.forEach((button) => (button.disabled = true));
    this.trayTarget.classList.add(...(correct ? RIGHT : WRONG), "border");
    this.settle(correct);
  }

  pickLeft(event) {
    if (this.settled) return;
    const button = event.currentTarget;
    if (button.disabled) return;
    this.leftTargets.forEach((other) => other.classList.remove("bg-muted"));
    button.classList.add("bg-muted");
    this.pendingLeft = button;
  }

  pickRight(event) {
    if (this.settled || !this.pendingLeft) return;
    const button = event.currentTarget;
    if (button.disabled) return;
    const same = button.dataset.slot === this.pendingLeft.dataset.slot;
    if (same) {
      [this.pendingLeft, button].forEach((element) => {
        element.disabled = true;
        element.classList.remove("bg-muted");
        element.classList.add(...RIGHT);
      });
      this.matched += 1;
      if (this.matched === this.leftTargets.length)
        this.settle(this.misses === 0);
    } else {
      this.misses += 1;
      button.classList.add(...WRONG);
      setTimeout(() => button.classList.remove(...WRONG), 600);
    }
    this.pendingLeft = null;
  }

  settle(correct) {
    this.settled = true;
    if (this.hasFeedbackTarget) {
      this.feedbackTarget.textContent = correct
        ? `✓ ${this.rightLabelValue}`
        : `✗ ${this.wrongLabelValue}`;
      this.feedbackTarget.classList.add(
        correct ? "text-emerald-600" : "text-red-500",
      );
    }
    this.dispatch("done", { detail: { correct } });
  }
}
