import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "panel", "results", "row"]
  static values = { url: String, delay: { type: Number, default: 140 } }

  connect() {
    this.onDocClick = (e) => { if (!this.element.contains(e.target)) this.hide() }
    document.addEventListener("click", this.onDocClick)
  }

  disconnect() {
    document.removeEventListener("click", this.onDocClick)
    clearTimeout(this.timer)
    if (this.controller) this.controller.abort()
  }

  input() {
    clearTimeout(this.timer)
    const q = this.inputTarget.value.trim()
    if (!q) return this.hide()
    this.timer = setTimeout(() => this.fetch(q), this.delayValue)
  }

  focus() {
    if (this.inputTarget.value.trim() && this.hasResult) this.show()
  }

  async fetch(q) {
    if (this.controller) this.controller.abort()
    this.controller = new AbortController()
    try {
      const url = `${this.urlValue}?q=${encodeURIComponent(q)}&frame=1`
      const res = await fetch(url, { headers: { Accept: "text/html" }, signal: this.controller.signal })
      if (!res.ok) return
      this.resultsTarget.innerHTML = await res.text()
      this.cursor = undefined
      this.hasResult = true
      this.show()
    } catch (e) {
      if (e.name !== "AbortError") this.hide()
    }
  }

  keydown(e) {
    if (e.key === "Escape") { this.hide(); this.inputTarget.blur() }
    if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      const rows = this.rowTargets
      if (!rows.length) return
      e.preventDefault()
      const step = e.key === "ArrowDown" ? 1 : -1
      this.cursor = this.cursor === undefined ? (step > 0 ? 0 : rows.length - 1) : this.cursor + step
      this.cursor = (this.cursor + rows.length) % rows.length
      rows.forEach((row, index) => row.classList.toggle("bg-muted", index === this.cursor))
      rows[this.cursor].scrollIntoView({ block: "nearest" })
    }
    if (e.key === "Enter") {
      const rows = this.rowTargets
      const target = this.cursor === undefined ? this.resultsTarget.querySelector("a[href]") : rows[this.cursor]
      if (target) { e.preventDefault(); window.location.href = target.href }
    }
  }

  show() { this.panelTarget.classList.remove("hidden") }

  hide() {
    this.panelTarget.classList.add("hidden")
    this.cursor = undefined
  }
}
