import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field", "panel", "pane", "tab", "opener"]

  connect() {
    this.dismiss = this.dismiss.bind(this)
    document.addEventListener("click", this.dismiss)
  }

  disconnect() {
    document.removeEventListener("click", this.dismiss)
  }

  toggle(event) {
    event.preventDefault()
    this.panelTarget.classList.toggle("hidden")
    if (!this.open) return

    this.fieldTarget.focus({ preventScroll: true })
  }

  close() {
    this.panelTarget.classList.add("hidden")
    this.fieldTarget.focus({ preventScroll: true })
  }

  dismiss(event) {
    if (!this.open) return
    if (this.element.contains(event.target)) return

    this.panelTarget.classList.add("hidden")
  }

  get open() {
    return !this.panelTarget.classList.contains("hidden")
  }

  pick(event) {
    const mode = event.currentTarget.dataset.mode

    this.tabTargets.forEach((tab) => tab.setAttribute("aria-pressed", String(tab.dataset.mode === mode)))
    this.paneTargets.forEach((pane) => pane.classList.toggle("hidden", pane.dataset.mode !== mode))
    this.fieldTarget.focus({ preventScroll: true })
  }

  insert(event) {
    event.preventDefault()
    this.write(event.currentTarget.dataset.symbol || "")
  }

  accept(event) {
    this.write(event.detail.character || "")
  }

  write(symbol) {
    if (!symbol) return

    const field = this.fieldTarget
    const start = field.selectionStart ?? field.value.length
    const end = field.selectionEnd ?? start

    field.value = field.value.slice(0, start) + symbol + field.value.slice(end)
    const caret = start + symbol.length
    field.setSelectionRange(caret, caret)
    field.focus({ preventScroll: true })
    field.dispatchEvent(new Event("input", { bubbles: true }))
  }

  backspace(event) {
    event.preventDefault()

    const field = this.fieldTarget
    const start = field.selectionStart ?? field.value.length
    const end = field.selectionEnd ?? start

    if (start === end && start === 0) return

    const from = start === end ? start - 1 : start
    field.value = field.value.slice(0, from) + field.value.slice(end)
    field.setSelectionRange(from, from)
    field.focus({ preventScroll: true })
    field.dispatchEvent(new Event("input", { bubbles: true }))
  }
}
