import { Controller } from "@hotwired/stimulus"
import HanziWriter from "hanzi-writer"
import { writerSize } from "lib/writer_size"

export default class extends Controller {
  static targets = ["square", "status", "result", "reveal"]
  static values = {
    gradeUrl: String,
    advanceUrl: String,
    lexemeId: String,
    labelDone: String,
    labelMistake: String,
    labelGood: String,
    labelHard: String,
    labelAgain: String,
  }

  connect() {
    this.startedAt = performance.now()
    this.writers = []
    this.done = []
    this.mistakes = []
    this.finished = false
    this.squareTargets.forEach((el, i) => this.build(el, i))
    this.setStatus(`0/${this.squareTargets.length}`)
  }

  disconnect() {
    this.writers.forEach((w) => w?.cancelQuiz())
  }

  build(el, i) {
    const char = el.dataset.char
    const url = el.dataset.url
    this.done[i] = false
    this.mistakes[i] = 0
    const side = writerSize(el.parentElement, this.squareTargets.length, { min: 150, max: 240 })
    const writer = HanziWriter.create(el, char, {
      width: side,
      height: side,
      padding: 6,
      showCharacter: false,
      showOutline: false,
      showHintAfterMisses: 3,
      strokeColor: "#18181b",
      drawingColor: "#10b981",
      charDataLoader: (c, onComplete) => fetch(url).then((r) => r.json()).then(onComplete),
    })
    this.writers[i] = writer
    writer.quiz({
      leniency: 1.0,
      showHintAfterMisses: 3,
      onMistake: () => { this.mistakes[i] += 1 },
      onComplete: () => this.completeChar(i, el),
    })
  }

  completeChar(i, el) {
    this.done[i] = true
    el.classList.add("border-emerald-500")
    const total = this.squareTargets.length
    const finished = this.done.filter(Boolean).length
    this.setStatus(`${finished}/${total}`)
    if (finished === total && !this.finished) this.finish()
  }

  finish() {
    this.finished = true
    const totalMistakes = this.mistakes.reduce((a, b) => a + b, 0)
    const rating = totalMistakes === 0 ? "good" : "hard"
    this.grade(rating)
    this.showResult(rating === "good" ? this.labelGoodValue : this.labelHardValue, rating === "good")
    this.advanceTimer = setTimeout(() => this.advance(), 1200)
  }

  reveal() {
    if (this.finished) return
    this.finished = true
    this.writers.forEach((w) => { w?.cancelQuiz(); w?.showCharacter(); w?.animateCharacter() })
    this.grade("again")
    this.showResult(this.labelAgainValue, false)
    if (this.hasRevealTarget) this.revealTarget.disabled = true
  }

  async grade(rating) {
    const body = new URLSearchParams({
      lexeme_id: this.lexemeIdValue,
      rating,
      elapsed_ms: Math.round(performance.now() - this.startedAt),
    })
    try {
      await fetch(this.gradeUrlValue, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded", "X-CSRF-Token": this.csrf() },
        body,
      })
    } catch {}
  }

  advance() {
    if (this.advanceUrlValue) window.location.href = this.advanceUrlValue
  }

  showResult(text, ok) {
    if (!this.hasResultTarget) return
    this.resultTarget.textContent = text
    this.resultTarget.classList.toggle("text-emerald-600", ok)
    this.resultTarget.classList.toggle("text-amber-600", !ok)
  }

  setStatus(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }

  csrf() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
