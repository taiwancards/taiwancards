import { Controller } from "@hotwired/stimulus"

const SETTLE_MS = 1100
const KEYS = { ArrowUp: "up", ArrowDown: "down", ArrowLeft: "left", ArrowRight: "right" }

export default class extends Controller {
  static targets = ["option", "form", "rating", "elapsed", "result"]
  static values = { labelCorrect: String, labelWrong: String }

  connect() {
    this.startedAt = performance.now()
    this.answered = false
    this.keyHandler = (event) => this.onKey(event)
    document.addEventListener("keydown", this.keyHandler)
  }

  disconnect() {
    document.removeEventListener("keydown", this.keyHandler)
    if (this.timer) clearTimeout(this.timer)
  }

  onKey(event) {
    const direction = KEYS[event.key]
    if (!direction) return

    const option = this.optionTargets.find((element) => element.dataset.direction === direction)
    if (!option) return

    event.preventDefault()
    this.answer(option)
  }

  choose(event) {
    const option = event.target.closest("[data-direction]")
    if (option) this.answer(option)
  }

  start(event) {
    if (this.answered) return
    if (event.button !== undefined && event.button !== 0) return

    this.dragging = true
    this.fromX = event.clientX
    this.fromY = event.clientY
    event.currentTarget.setPointerCapture(event.pointerId)
    event.currentTarget.style.transition = "none"
  }

  move(event) {
    if (!this.dragging) return

    const dx = event.clientX - this.fromX
    const dy = event.clientY - this.fromY
    event.currentTarget.style.transform = `translate(${dx}px, ${dy}px)`
  }

  end(event) {
    if (!this.dragging) return

    this.dragging = false
    const card = event.currentTarget
    const dx = event.clientX - this.fromX
    const dy = event.clientY - this.fromY
    card.style.transition = "transform 200ms ease-out"
    card.style.transform = ""

    const direction = this.direction(dx, dy, card.offsetWidth * 0.25, card.offsetHeight * 0.2)
    if (!direction) return

    const option = this.optionTargets.find((element) => element.dataset.direction === direction)
    if (option) this.answer(option)
  }

  direction(dx, dy, thresholdX, thresholdY) {
    if (Math.abs(dy) > Math.abs(dx)) {
      if (dy < -thresholdY) return "up"
      if (dy > thresholdY) return "down"
      return null
    }
    if (dx > thresholdX) return "right"
    if (dx < -thresholdX) return "left"
    return null
  }

  answer(option) {
    if (this.answered) return

    this.answered = true
    const correct = option.dataset.correct === "true"
    this.mark(option, correct)
    this.reveal()
    this.show(correct ? this.labelCorrectValue : this.labelWrongValue, correct)
    this.timer = setTimeout(() => this.submit(correct ? "good" : "again"), SETTLE_MS)
  }

  mark(option, correct) {
    option.classList.add(correct ? "border-emerald-500" : "border-red-500")
    option.classList.add(correct ? "bg-emerald-500/10" : "bg-red-500/10")
  }

  reveal() {
    for (const element of this.optionTargets) {
      element.disabled = true
      if (element.dataset.correct === "true") element.classList.add("border-emerald-500")
    }
  }

  show(text, ok) {
    if (!this.hasResultTarget) return

    this.resultTarget.textContent = text
    this.resultTarget.classList.toggle("text-emerald-600", ok)
    this.resultTarget.classList.toggle("text-red-600", !ok)
  }

  submit(rating) {
    this.ratingTarget.value = rating
    if (this.hasElapsedTarget) this.elapsedTarget.value = Math.round(performance.now() - this.startedAt)
    this.formTarget.requestSubmit()
  }
}
