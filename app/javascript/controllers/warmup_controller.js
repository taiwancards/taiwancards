import { Controller } from "@hotwired/stimulus"
import { playClip } from "lib/clip"

const SILENCE_RMS = 0.015
const MIN_MS = 900
const MAX_MS = 4000
const MIC_SETTLE_MS = 150

export default class extends Controller {
  static targets = ["record", "status", "prompt", "hint", "step", "pip", "reading", "replay"]
  static values = {
    url: String,
    doneUrl: String,
    prompts: Array,
    labelRecord: String,
    labelListening: String,
    labelRecording: String,
    labelSaved: String,
    labelError: String,
    labelMicDenied: String,
    labelMicMissing: String,
    labelMicInsecure: String,
    labelDone: String,
    labelAnchors: String,
  }

  connect() {
    this.index = 0
    this.recording = false
    this.showPrompt()
  }

  disconnect() {
    this.teardown()
  }

  showPrompt() {
    const prompt = this.promptsValue[this.index]
    if (!prompt) return
    this.promptTarget.textContent = prompt.text
    this.promptTarget.lang = prompt.zhuyin ? "zh-TW" : ""
    this.hintTarget.textContent = prompt.hint
    this.showReading(prompt)
    this.reference = prompt.audio ? { url: prompt.audio, stop: prompt.audio_stop } : null
    this.replayTarget.classList.toggle("hidden", !this.reference)
    if (this.reference) this.playReference()
    this.stepTarget.textContent = `${this.index + 1} / ${this.promptsValue.length}`
  }

  showReading(prompt) {
    const parts = [prompt.zhuyin, prompt.pinyin].filter(Boolean)
    this.readingTarget.textContent = parts.join("  ")
    this.readingTarget.classList.toggle("hidden", parts.length === 0)
  }

  replay() {
    if (this.reference) this.playReference()
  }

  silenceReference() {
    this.referenceClip?.stop()
    this.referenceClip = null
  }

  playReference() {
    this.silenceReference()
    this.referenceClip = playClip(this.reference.url, Number(this.reference.stop) || 0)
  }

  markPip(index, color) {
    const pip = this.pipTargets[index]
    if (pip) pip.style.backgroundColor = color
  }

  async toggle() {
    if (this.recording) return this.stop()
    await this.start()
  }

  async start() {
    this.silenceReference()
    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    } catch (error) {
      this.statusTarget.textContent = this.micProblem(error)
      return
    }
    await new Promise((resolve) => setTimeout(resolve, MIC_SETTLE_MS))
    if (!this.stream) return

    this.chunks = []
    this.recorder = new MediaRecorder(this.stream)
    this.recorder.ondataavailable = (e) => e.data.size && this.chunks.push(e.data)
    this.recorder.onstop = () => this.upload()
    this.recorder.start()
    this.recording = true
    this.recordTarget.textContent = this.labelListeningValue
    this.statusTarget.textContent = this.labelRecordingValue
    this.watch()
  }

  micProblem(error) {
    if (window.isSecureContext === false) return this.labelMicInsecureValue
    if (["NotFoundError", "OverconstrainedError"].includes(error?.name)) return this.labelMicMissingValue
    return this.labelMicDeniedValue
  }

  stop() {
    if (!this.recording) return
    this.recording = false
    this.teardown()
    this.recorder?.stop()
    this.stream?.getTracks().forEach((t) => t.stop())
    this.recordTarget.textContent = this.labelRecordValue
  }

  watch() {
    try {
      this.ctx = new (window.AudioContext || window.webkitAudioContext)()
      const source = this.ctx.createMediaStreamSource(this.stream)
      this.analyser = this.ctx.createAnalyser()
      this.analyser.fftSize = 1024
      source.connect(this.analyser)
      this.buf = new Float32Array(this.analyser.fftSize)
      this.startedAt = performance.now()
      this.lastLoud = this.startedAt
      this.timer = setInterval(() => this.tick(), 80)
    } catch {
      this.maxTimer = setTimeout(() => this.stop(), MAX_MS)
    }
  }

  tick() {
    if (!this.analyser) return
    this.analyser.getFloatTimeDomainData(this.buf)
    let sum = 0
    for (let i = 0; i < this.buf.length; i++) sum += this.buf[i] * this.buf[i]
    const rms = Math.sqrt(sum / this.buf.length)
    const now = performance.now()
    if (rms > SILENCE_RMS) this.lastLoud = now
    const elapsed = now - this.startedAt
    if (elapsed > MAX_MS || (elapsed > MIN_MS && now - this.lastLoud > 700)) this.stop()
  }

  teardown() {
    clearInterval(this.timer)
    clearTimeout(this.maxTimer)
    this.analyser = null
    if (this.ctx) {
      this.ctx.close().catch(() => {})
      this.ctx = null
    }
  }

  async upload() {
    const prompt = this.promptsValue[this.index]
    let wav
    try {
      wav = await this.toWav(new Blob(this.chunks, { type: this.recorder.mimeType || "audio/webm" }))
    } catch {
      this.statusTarget.textContent = this.labelErrorValue
      return
    }

    const form = new FormData()
    form.append("audio", wav, "warmup.wav")
    form.append("kind", prompt.kind)
    form.append("prompt_id", prompt.id)
    if (prompt.tone) form.append("tone", prompt.tone)

    try {
      const headers = {}
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      if (token) headers["X-CSRF-Token"] = token
      const res = await fetch(this.urlValue, { method: "POST", body: form, headers })
      const body = await res.json()
      if (!body.ok) {
        this.statusTarget.textContent = this.labelErrorValue
        this.markPip(this.index, "#ef4444")
        return
      }
      this.markPip(this.index, "#10b981")
      this.statusTarget.textContent = this.labelSavedValue
      this.summary = body.summary
      this.next()
    } catch {
      this.statusTarget.textContent = this.labelErrorValue
    }
  }

  firstToneStep() {
    return this.promptsValue.findIndex((p) => p.kind === "tone")
  }

  rewindToTones() {
    const start = this.firstToneStep()
    if (start < 0) return false

    this.retried = true
    this.index = start
    this.promptsValue.forEach((p, i) => p.kind === "tone" && this.markPip(i, ""))
    this.showPrompt()
    this.statusTarget.textContent = this.labelAnchorsValue || this.labelDoneValue
    return true
  }

  next() {
    this.index += 1
    if (this.index < this.promptsValue.length) return this.showPrompt()

    if (this.summary?.anchors_sane === false && !this.retried && this.rewindToTones()) return

    this.statusTarget.textContent = this.labelDoneValue
    setTimeout(() => {
      window.location.href = this.doneUrlValue || window.location.href
    }, 900)
  }

  async toWav(blob) {
    const ctx = new (window.AudioContext || window.webkitAudioContext)()
    try {
      const buffer = await ctx.decodeAudioData(await blob.arrayBuffer())
      return this.encodeWav(buffer)
    } finally {
      ctx.close()
    }
  }

  encodeWav(audioBuffer) {
    const sr = audioBuffer.sampleRate
    const samples = audioBuffer.getChannelData(0)
    const out = new ArrayBuffer(44 + samples.length * 2)
    const view = new DataView(out)
    const str = (off, s) => { for (let i = 0; i < s.length; i++) view.setUint8(off + i, s.charCodeAt(i)) }
    str(0, "RIFF"); view.setUint32(4, 36 + samples.length * 2, true); str(8, "WAVE")
    str(12, "fmt "); view.setUint32(16, 16, true); view.setUint16(20, 1, true); view.setUint16(22, 1, true)
    view.setUint32(24, sr, true); view.setUint32(28, sr * 2, true); view.setUint16(32, 2, true); view.setUint16(34, 16, true)
    str(36, "data"); view.setUint32(40, samples.length * 2, true)
    let off = 44
    for (let i = 0; i < samples.length; i++) {
      const s = Math.max(-1, Math.min(1, samples[i]))
      view.setInt16(off, s < 0 ? s * 0x8000 : s * 0x7fff, true)
      off += 2
    }
    return new Blob([out], { type: "audio/wav" })
  }
}
