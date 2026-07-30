import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this.onDocClick = (event) => {
      if (!this.element.contains(event.target)) this.close()
    }
    this.onKey = (event) => {
      if (event.key === "Escape") this.close()
    }
    document.addEventListener("click", this.onDocClick)
    document.addEventListener("keydown", this.onKey)
  }

  disconnect() {
    document.removeEventListener("click", this.onDocClick)
    document.removeEventListener("keydown", this.onKey)
  }

  toggle(event) {
    event.stopPropagation()
    const opening = this.panelTarget.classList.contains("hidden")
    document.querySelectorAll("[data-menu-target=panel]").forEach((p) => p.classList.add("hidden"))
    if (opening) this.panelTarget.classList.remove("hidden")
  }

  close() {
    this.panelTarget.classList.add("hidden")
  }
}
