import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["select", "note"];

  show() {
    const level = this.selectTarget.value;
    this.noteTargets.forEach((note) => {
      note.hidden = note.dataset.level !== level;
      note.classList.toggle("hidden", note.hidden);
    });
  }
}
