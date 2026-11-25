import { Controller } from "@hotwired/stimulus";
import { best, history } from "lib/exam_paper";

export default class extends Controller {
  static targets = ["best"];
  static values = { template: String };

  connect() {
    const all = history();
    for (const node of this.bestTargets) {
      if (node.textContent.trim()) continue;
      const top = best(all[node.dataset.slug]);
      if (!top) continue;
      node.textContent = this.templateValue
        .replace("%{score}", top.raw)
        .replace("%{total}", top.total);
      node.hidden = false;
    }
  }
}
