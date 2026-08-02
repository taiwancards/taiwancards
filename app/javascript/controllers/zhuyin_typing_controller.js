import { Controller } from "@hotwired/stimulus"

const TONES = { "6": "ˊ", "3": "ˇ", "4": "ˋ", "7": "˙" }

export default class extends Controller {
  static targets = ["prompt", "meaning", "buffer", "expected", "verdict", "key", "score", "streak"]
  static values = { words: Array, keys: Object, resultUrl: String, goal: Number }

  connect() {
    this.index = 0
    this.correct = 0
    this.attempts = 0
    this.reported = false
    this.buffer = ""
    this.handler = (event) => this.onKey(event)
    document.addEventListener("keydown", this.handler)
    this.render()
  }

  disconnect() {
    document.removeEventListener("keydown", this.handler)
  }

  get word() {
    return this.wordsValue[this.index % this.wordsValue.length]
  }

  onKey(event) {
    if (event.metaKey || event.ctrlKey || event.altKey) return

    const key = event.key
    if (key === "Backspace") {
      event.preventDefault()
      return this.erase()
    }
    if (key === "Enter" || key === " ") {
      event.preventDefault()
      return this.submit()
    }

    const lower = key.toLowerCase()
    const symbol = this.keysValue[lower] || TONES[lower]
    if (symbol === undefined) return

    event.preventDefault()
    this.buffer += symbol
    this.flash(lower)
    this.afterInput()
  }

  tap(event) {
    const key = event.currentTarget.dataset.key
    if (key === " " || key === "Enter") return this.submit()
    if (key === "Backspace") return this.erase()

    const symbol = this.keysValue[key] || TONES[key]
    if (symbol === undefined) return

    this.buffer += symbol
    this.flash(key)
    this.afterInput()
  }

  erase() {
    this.buffer = this.buffer.slice(0, -1)
    this.render()
  }

  afterInput() {
    const state = this.matches()
    this.render()

    if (state.exact) return this.accept()

    this.bufferTarget.dataset.state = state.prefix ? "typing" : "bad"
  }

  accept() {
    this.attempts += 1
    this.correct += 1
    this.bufferTarget.dataset.state = "ok"
    this.verdictTarget.dataset.state = "ok"
    this.verdictTarget.textContent = "\u2713"
    this.index += 1
    this.buffer = ""
    this.report()

    setTimeout(() => {
      this.bufferTarget.dataset.state = ""
      this.verdictTarget.textContent = ""
      this.verdictTarget.dataset.state = ""
      this.render()
    }, 420)
  }

  flash(key) {
    const node = this.keyTargets.find((candidate) => candidate.dataset.key === key)
    if (!node) return
    node.dataset.hit = "true"
    setTimeout(() => { node.dataset.hit = "false" }, 140)
  }

  normalize(value) {
    return value.replace(/\s+/g, "")
  }

  submit() {
    if (!this.buffer) return

    this.attempts += 1
    const expected = this.normalize(this.word.zhuyin)
    const ok = this.normalize(this.buffer) === expected

    if (ok) this.correct += 1
    this.verdictTarget.dataset.state = ok ? "ok" : "bad"
    this.verdictTarget.textContent = ok ? "✓" : expected

    this.buffer = ""
    if (ok) this.index += 1
    this.render()
    this.report()
  }

  report() {
    if (this.reported || !this.resultUrlValue) return
    if (this.correct < (this.goalValue || 10)) return

    this.reported = true
    const token = document.querySelector("meta[name='csrf-token']")?.content
    fetch(this.resultUrlValue, {
      method: "POST",
      headers: { "X-CSRF-Token": token || "" }
    }).catch(() => {})
  }

  matches() {
    const expected = this.normalize(this.word.zhuyin)
    const typed = this.normalize(this.buffer)
    return {exact: typed === expected, prefix: expected.startsWith(typed)}
  }

  render() {
    const word = this.word
    this.promptTarget.textContent = word.prompt || word.text
    this.meaningTarget.textContent = word.meaning || ""
    this.bufferTarget.textContent = this.buffer || "…"
    this.expectedTarget.textContent = word.zhuyin
    this.scoreTarget.textContent = `${this.correct} / ${this.attempts}`
    this.streakTarget.textContent = String(this.index)
  }

  reveal() {
    this.expectedTarget.dataset.shown = this.expectedTarget.dataset.shown === "true" ? "false" : "true"
  }

  skip() {
    this.index += 1
    this.buffer = ""
    this.verdictTarget.textContent = ""
    this.verdictTarget.dataset.state = ""
    this.render()
  }
}
