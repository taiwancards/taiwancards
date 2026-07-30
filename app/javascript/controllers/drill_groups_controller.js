import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "group"]
  static values = { active: String }

  connect() {
    this.show(this.activeValue || this.tabTargets[0]?.dataset.group)
  }

  select(event) {
    this.show(event.currentTarget.dataset.group)
  }

  show(name) {
    this.groupTargets.forEach((el) => el.classList.toggle("hidden", el.dataset.group !== name))
    this.tabTargets.forEach((tab) => {
      const on = tab.dataset.group === name
      tab.classList.toggle("border-primary", on)
      tab.classList.toggle("bg-primary/10", on)
      tab.classList.toggle("text-primary", on)
      tab.classList.toggle("border-border", !on)
    })
  }
}
