import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["tab", "panel"];
  static values = { active: { type: String, default: "" } };

  connect() {
    if (!this.activeValue && this.tabTargets.length > 0) {
      this.activeValue = this.tabTargets[0].dataset.tabName;
    }
    this.render();
  }

  select(event) {
    this.activeValue = event.currentTarget.dataset.tabName;
    this.render();
  }

  render() {
    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.tabName === this.activeValue;
      tab.setAttribute("aria-selected", active);
      tab.classList.toggle("bg-primary", active);
      tab.classList.toggle("text-primary-foreground", active);
      tab.classList.toggle("text-muted-foreground", !active);
    });
    this.panelTargets.forEach((panel) => {
      panel.classList.toggle(
        "hidden",
        panel.dataset.tabName !== this.activeValue,
      );
    });
  }
}
