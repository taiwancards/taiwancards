import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["scheme", "grade"];

  connect() {
    this.syncGrades();
  }

  submit() {
    this.element.requestSubmit();
  }

  changeScheme() {
    this.gradeTarget.value = "";
    this.syncGrades();
    this.submit();
  }

  syncGrades() {
    if (!this.hasSchemeTarget || !this.hasGradeTarget) return;

    const scheme = this.schemeTarget.value;
    this.gradeTarget.disabled = scheme === "";
    Array.from(this.gradeTarget.options).forEach((option) => {
      const owner = option.dataset.scheme;
      option.hidden = Boolean(owner) && owner !== scheme;
    });
  }
}
