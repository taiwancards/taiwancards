import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "glyph", "reading", "counter", "known", "normal", "board", "summary", "left"]
  static values = { items: Array, url: String }

  connect() {
    this.keyHandler = (event) => this.onKey(event)
    document.addEventListener("keydown", this.keyHandler)
    this.begin()
  }

  disconnect() {
    document.removeEventListener("keydown", this.keyHandler)
    this.flush()
  }

  begin() {
    this.queue = [...this.itemsValue]
    this.planned = this.queue.length
    this.knownIds = []
    this.normalIds = []
    this.render()
  }

  render() {
    if (this.queue.length === 0) return this.finish()

    this.current = this.queue[0]
    this.glyphTarget.textContent = this.current.text
    this.readingTarget.textContent = this.current.zhuyin || ""
    this.counterTarget.textContent = `${this.planned - this.queue.length} / ${this.planned}`
    this.knownTarget.textContent = this.knownIds.length
    this.normalTarget.textContent = this.normalIds.length
    this.resetCard()
  }

  onKey(event) {
    if (event.key === "ArrowRight") {
      event.preventDefault()
      this.mark(true)
    } else if (event.key === "ArrowLeft") {
      event.preventDefault()
      this.mark(false)
    }
  }

  markKnown() {
    this.mark(true)
  }

  markNormal() {
    this.mark(false)
  }

  mark(known) {
    if (!this.current) return

    if (known) this.knownIds.push(this.current.id)
    else this.normalIds.push(this.current.id)

    this.queue.shift()
    this.render()
  }

  start(event) {
    if (event.target.closest("button, a")) return
    this.startX = event.clientX
    this.dragging = true
  }

  move(event) {
    if (!this.dragging) return
    const dx = event.clientX - this.startX
    this.cardTarget.style.transition = ""
    this.cardTarget.style.transform = `translateX(${dx * 0.5}px) rotate(${dx * 0.02}deg)`
  }

  end(event) {
    if (!this.dragging) return
    this.dragging = false
    const dx = event.clientX - this.startX

    if (Math.abs(dx) < 40) return this.resetCard()
    this.mark(dx > 0)
  }

  resetCard() {
    this.cardTarget.style.transition = "transform 120ms ease-out"
    this.cardTarget.style.transform = ""
  }

  finish() {
    this.current = null
    this.boardTarget.classList.add("hidden")
    this.summaryTarget.classList.remove("hidden")
    this.flush()
  }

  async flush() {
    if (this.sent) return
    if (this.knownIds.length === 0 && this.normalIds.length === 0) return

    this.sent = true
    try {
      await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
        },
        body: JSON.stringify({ known: this.knownIds, normal: this.normalIds })
      })
    } catch {
      this.sent = false
    }
  }
}
