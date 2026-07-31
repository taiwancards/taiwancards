import { Controller } from "@hotwired/stimulus"
import { SpeechRecorder } from "lib/speech_recorder"

const LEVEL_CLASS = {
  green: "border-emerald-500 text-emerald-600",
  amber: "border-amber-500 text-amber-600",
  red: "border-red-500 text-red-600",
  dark: "border-red-600 text-red-700",
}

export default class extends Controller {
  static targets = ["record", "status", "syllable", "score", "attempts", "next", "form", "rating", "elapsed"]
  static values = {
    url: String,
    lexemeId: String,
    expected: Array,
    autoMs: Number,
    maxMs: Number,
    goodAt: Number,
    hardAt: Number,
    labelRecord: String,
    labelStop: String,
    labelListening: String,
    labelScoring: String,
    labelMicDenied: String,
    labelOffline: String,
    labelAttempts: String,
  }

  connect() {
    this.startedAt = performance.now()
    this.recorder = new SpeechRecorder()
    this.scores = []
    this.busy = false
    if (this.autoMsValue > 0) this.autoTimer = setTimeout(() => this.toggle(), this.autoMsValue)
  }

  disconnect() {
    for (const key of ["autoTimer", "stopTimer"]) if (this[key]) clearTimeout(this[key])
    this.recorder?.release()
  }

  async toggle() {
    if (this.busy) return
    if (this.recorder.recording) return this.finishRecording()

    this.clearAuto()
    this.busy = true
    const started = await this.recorder.start()
    this.busy = false
    if (!started) return this.setStatus(this.labelMicDeniedValue)

    this.recordTarget.textContent = this.labelStopValue
    this.recordTarget.classList.add("bg-red-500", "text-white")
    this.setStatus(this.labelListeningValue)
    this.stopTimer = setTimeout(() => this.finishRecording(), this.maxMsValue || 6000)
  }

  async finishRecording() {
    if (this.stopTimer) clearTimeout(this.stopTimer)
    this.recordTarget.textContent = this.labelRecordValue
    this.recordTarget.classList.remove("bg-red-500", "text-white")

    const wav = await this.recorder.stop()
    if (!wav) return this.setStatus("")

    this.setStatus(this.labelScoringValue)
    await this.grade(wav)
  }

  async grade(wav) {
    const form = new FormData()
    form.append("audio", wav, "utterance.wav")
    form.append("tonal", "true")
    form.append("expected", JSON.stringify(this.expectedValue))
    form.append("text", this.expectedValue.map((part) => part.char).join(""))
    form.append("lexeme_id", this.lexemeIdValue)
    form.append("schedule", "false")

    try {
      const headers = {}
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      if (token) headers["X-CSRF-Token"] = token
      const response = await fetch(`${this.urlValue}/grade`, { method: "POST", body: form, headers })
      if (response.status === 503) return this.offline()
      if (!response.ok) return this.setStatus("")

      this.render(await response.json())
    } catch {
      this.setStatus("")
    }
  }

  render(result) {
    this.setStatus("")
    const syllables = Array.isArray(result.syllables) ? result.syllables : []

    syllables.forEach((syllable, index) => {
      const element = this.syllableTargets[index]
      if (!element || !syllable) return

      element.className = `${element.dataset.base} ${LEVEL_CLASS[syllable.level] || "border-border"}`
      const heard = element.querySelector("[data-heard]")
      if (heard) heard.textContent = syllable.heard || syllable.recognized || ""
    })

    const overall = Math.round(Number(result.overall ?? this.average(syllables)) || 0)
    this.scores.push(overall)
    this.paintScore()
    if (this.hasNextTarget) this.nextTarget.hidden = false
  }

  average(syllables) {
    const values = syllables.filter(Boolean).map((syllable) => Number(syllable.overall) || 0)
    return values.length ? values.reduce((a, b) => a + b, 0) / values.length : 0
  }

  paintScore() {
    const mean = Math.round(this.scores.reduce((a, b) => a + b, 0) / this.scores.length)
    if (this.hasScoreTarget) this.scoreTarget.textContent = mean
    if (this.hasAttemptsTarget) {
      this.attemptsTarget.textContent = this.labelAttemptsValue.replace("%{count}", this.scores.length)
    }
  }

  offline() {
    this.setStatus(this.labelOfflineValue)
    if (this.hasNextTarget) this.nextTarget.hidden = false
  }

  advance() {
    this.submit(this.verdict())
  }

  verdict() {
    if (this.scores.length === 0) return "hard"

    const mean = this.scores.reduce((a, b) => a + b, 0) / this.scores.length
    if (mean >= this.goodAtValue) return "good"
    if (mean >= this.hardAtValue) return "hard"
    return "again"
  }

  submit(rating) {
    this.ratingTarget.value = rating
    if (this.hasElapsedTarget) this.elapsedTarget.value = Math.round(performance.now() - this.startedAt)
    this.formTarget.requestSubmit()
  }

  clearAuto() {
    if (this.autoTimer) clearTimeout(this.autoTimer)
    this.autoTimer = null
  }

  setStatus(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }
}
