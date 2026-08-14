import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["tally", "score"];
  static values = { total: Number };

  connect() {
    this.correct = 0;
    this.answered = 0;
    this.render();
  }

  record(event) {
    this.answered += 1;
    if (event.detail.correct) this.correct += 1;
    this.render();
  }

  render() {
    if (this.hasTallyTarget) {
      this.tallyTarget.textContent = `${this.correct} / ${this.totalValue}`;
    }
    if (this.hasScoreTarget) this.scoreTarget.value = this.correct;
  }
}
