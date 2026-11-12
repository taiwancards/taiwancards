import { Controller } from "@hotwired/stimulus";
import { typingElsewhere } from "lib/hotkeys";

export default class extends Controller {
  static targets = ["choice"];

  connect() {
    this.onKeydown = this.handleKeydown.bind(this);
    document.addEventListener("keydown", this.onKeydown);
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown);
  }

  handleKeydown(event) {
    if (typingElsewhere(event)) return;

    const index = Number(event.key) - 1;
    if (Number.isNaN(index) || index < 0 || index >= this.choiceTargets.length)
      return;

    event.preventDefault();
    this.choiceTargets[index].requestSubmit();
  }
}
