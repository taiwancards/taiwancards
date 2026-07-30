import { Controller } from "@hotwired/stimulus"
import HanziWriter from "hanzi-writer"

export default class extends Controller {
  static targets = ["canvas", "status"]
  static values = { char: String, url: String, size: { type: Number, default: 220 } }

  connect() {
    this.writer = HanziWriter.create(this.canvasTarget, this.charValue, {
      width: this.sizeValue,
      height: this.sizeValue,
      padding: 8,
      showCharacter: true,
      showOutline: true,
      strokeAnimationSpeed: 1,
      delayBetweenStrokes: 180,
      strokeColor: this.strokeColor(),
      outlineColor: this.outlineColor(),
      drawingColor: "#10b981",
      charDataLoader: (char, onComplete) => {
        fetch(this.urlValue)
          .then((response) => response.json())
          .then(onComplete)
      },
    })
  }

  disconnect() {
    this.writer?.cancelQuiz()
    this.canvasTarget.replaceChildren()
  }

  animate() {
    this.setStatus("")
    this.writer.animateCharacter()
  }

  quiz() {
    this.setStatus(this.statusTarget?.dataset.practicing || "")
    this.writer.quiz({
      leniency: 1.0,
      showHintAfterMisses: 3,
      onMistake: (data) => this.setStatus(`✗ ${data.strokeNum + 1}/${this.totalStrokes(data, false)}`),
      onCorrectStroke: (data) => this.setStatus(`${data.strokeNum + 1}/${this.totalStrokes(data, true)}`),
      onComplete: () => this.setStatus(this.statusTarget?.dataset.done || "✓"),
    })
  }

  totalStrokes(data, correct) {
    return data.strokeNum + data.strokesRemaining + (correct ? 1 : 0)
  }

  setStatus(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }

  dark() {
    return document.documentElement.classList.contains("dark")
  }

  strokeColor() {
    return this.dark() ? "#f4f4f5" : "#18181b"
  }

  outlineColor() {
    return this.dark() ? "#3f3f46" : "#d4d4d8"
  }
}
