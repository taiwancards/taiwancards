import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["query", "item", "section", "empty"];

  run() {
    const needle = this.queryTarget.value.trim().toLocaleLowerCase();
    let shown = 0;

    this.itemTargets.forEach((item) => {
      const hit = !needle || (item.dataset.filterText || "").includes(needle);
      item.classList.toggle("hidden", !hit);
      if (hit) shown += 1;
    });

    this.sectionTargets.forEach((section) => {
      const alive = [
        ...section.querySelectorAll('[data-filter-target="item"]'),
      ].some((item) => !item.classList.contains("hidden"));
      section.classList.toggle("hidden", !alive);
    });

    if (this.hasEmptyTarget)
      this.emptyTarget.classList.toggle("hidden", shown > 0);
  }

  clear() {
    this.queryTarget.value = "";
    this.run();
  }
}
