import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "panel"]

  toggle() {
    this.panelTarget.classList.toggle("hidden")
    if (!this.panelTarget.classList.contains("hidden")) this.inputTarget.focus()
  }

  insert(event) {
    event.preventDefault()
    const symbol = event.currentTarget.dataset.keypadSymbol || ""
    const input = this.inputTarget
    const start = input.selectionStart ?? input.value.length
    const end = input.selectionEnd ?? start
    input.value = input.value.slice(0, start) + symbol + input.value.slice(end)
    const caret = start + symbol.length
    input.setSelectionRange(caret, caret)
    input.focus()
  }

  backspace(event) {
    event.preventDefault()
    const input = this.inputTarget
    const start = input.selectionStart ?? input.value.length
    const end = input.selectionEnd ?? start
    const from = start === end ? Math.max(0, start - 1) : start
    input.value = input.value.slice(0, from) + input.value.slice(end)
    input.setSelectionRange(from, from)
    input.focus()
  }

  clear(event) {
    event.preventDefault()
    this.inputTarget.value = ""
    this.inputTarget.focus()
  }
}
