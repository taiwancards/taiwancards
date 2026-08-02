import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["card", "option", "feedback"];
  static values = { correct: String, nextUrl: String };

  connect() {
    this.answered = false;
    this.keyHandler = (event) => this.onKey(event);
    document.addEventListener("keydown", this.keyHandler);
  }

  disconnect() {
    document.removeEventListener("keydown", this.keyHandler);
    clearTimeout(this.advanceTimer);
  }

  onKey(event) {
    const map = {
      ArrowUp: "up",
      ArrowRight: "right",
      ArrowDown: "down",
      ArrowLeft: "left",
    };
    if (map[event.key]) {
      event.preventDefault();
      this.answer(map[event.key]);
    }
  }

  choose(event) {
    this.answer(event.currentTarget.dataset.direction);
  }

  start(event) {
    this.startX = event.clientX;
    this.startY = event.clientY;
  }

  end(event) {
    const dx = event.clientX - this.startX;
    const dy = event.clientY - this.startY;
    if (Math.abs(dx) < 24 && Math.abs(dy) < 24) return;
    const direction =
      Math.abs(dx) > Math.abs(dy)
        ? dx > 0
          ? "right"
          : "left"
        : dy > 0
          ? "down"
          : "up";
    this.answer(direction);
  }

  answer(direction) {
    if (this.answered) return;
    this.answered = true;
    const chosen = this.optionTargets.find(
      (o) => o.dataset.direction === direction,
    );
    const correctOption = this.optionTargets.find(
      (o) => o.dataset.correct === "true",
    );
    const isCorrect = chosen && chosen.dataset.correct === "true";

    if (chosen && !isCorrect) {
      chosen.classList.remove("border-border");
      chosen.classList.add("border-red-500", "bg-red-500/10");
    }
    if (correctOption) {
      correctOption.classList.remove("border-border");
      correctOption.classList.add("border-emerald-500", "bg-emerald-500/10");
    }

    if (this.hasFeedbackTarget) {
      this.feedbackTarget.textContent = isCorrect
        ? "✓"
        : `✗ ${this.correctValue}`;
      this.feedbackTarget.classList.add(
        isCorrect ? "text-emerald-600" : "text-red-500",
      );
    }

    this.advanceTimer = setTimeout(
      () => {
        if (this.nextUrlValue) window.location.href = this.nextUrlValue;
      },
      isCorrect ? 900 : 2000,
    );
  }
}
