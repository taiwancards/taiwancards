import { Controller } from "@hotwired/stimulus"
import { toWav } from "lib/speech_recorder"

const PRELISTEN_KEY = "pron_prelisten"
const SPEECH_RMS = 0.02
const MAX_DRILL_TRIES = 5
const REFERENCE_GRACE_MS = 400

const LEVELS = {
  green: "#10b981",
  amber: "#f59e0b",
  red: "#ef4444",
  dark: "#b91c1c",
  gray: "#9ca3af",
  none: "#d1d5db",
}

const PART_ORDER = ["initial", "medial", "final", "tone"]

const BARS = "▁▂▃▄▅▆▇█"
const LEVEL_MARK = { green: "4", amber: "3", red: "2", dark: "1", gray: "0", none: "_" }
const STYLE_MARK = {
  citation: "s1",
  mixed: "s0",
  word: "s2",
  word_initial: "s3",
  word_medial: "s4",
  "citation+word_initial": "s5",
  "wi+citation": "s6",
  "wm+word": "s7",
  "word+citation": "s8",
}
const CONF_MARK = { high: "3", medium: "2", low: "1", very_low: "0" }
const AXIS_MARK = {
  tone: "z4",
  initial: "z9",
  sibilant: "z1",
  medial: "z6",
  vowel: "z3",
  coda: "z8",
  timbre: "z2",
  duration: "z7",
}
const CODE_MARK = {
  near: "c0",
  "tone.wrong": "c7",
  "tone.shape": "c2",
  "initial.under_aspirated": "c9",
  "initial.over_aspirated": "c4",
  "initial.vot_off": "c1",
  "sibilant.too_front": "c6",
  "sibilant.too_back": "c3",
  "medial.weak": "c8",
  "vowel.open": "c5",
  "vowel.close": "cb",
  "vowel.front": "cd",
  "vowel.back": "cf",
  "coda.weak": "ch",
  "coda.ng_for_n": "ck",
  "coda.n_for_ng": "cm",
  "duration.long": "cp",
  "duration.short": "cr",
  "duration.neutral_long": "ct",
  "timbre.drift": "cw",
}
const FIELD_MARK = {
  vot_ms: "q7",
  fric_ms: "q2",
  fric_centroid: "q9",
  fric_spread: "q4",
  centroid_ratio: "q1",
  f1_ratio: "q6",
  f2_ratio: "q3",
  f2_end_ratio: "q8",
  nasal_ratio_tail: "q5",
  nasal_antiformant: "qb",
  duration_ms: "qd",
  voiced_ms: "qf",
  tone_range: "qh",
  tone_slope: "qk",
  f0_register: "qm",
}

export default class extends Controller {
  static targets = ["record", "status", "syllable", "prelisten", "card", "detail"]
  static values = {
    labelNotRecognized: String,
    labelNotMeasured: String,
    labelNoPart: String,
    labelNoTemplate: String,
    labelPartsTitle: String,
    labelFixTitle: String,
    labelChartHint: String,
    labelWeight: String,
    tonal: { type: Boolean, default: true },
    url: String,
    expected: Array,
    text: String,
    lexemeId: Number,
    audioUrl: String,
    audioStop: Number,
    audioParts: Array,
    silenceMs: Number,
    maxMs: Number,
    labelRecord: String,
    labelListening: String,
    labelRecording: String,
    labelGrading: String,
    labelDetails: String,
    labelCopy: String,
    labelUnavailable: String,
    labelMicDenied: String,
    labelMicMissing: String,
    labelMicInsecure: String,
    labelNetwork: String,
    labelError: String,
    labelRetry: String,
    labelDrill: String,
    labelDrillSkip: String,
    labelSilence: String,
  }

  connect() {
    this.recording = false
    this.mode = "word"
    this.prelisten = localStorage.getItem(PRELISTEN_KEY) === "1"
    if (this.hasPrelistenTarget) this.prelistenTarget.checked = this.prelisten
    this.checkHealth()
  }

  disconnect() {
    this.clearTimers()
    this.teardownMeter()
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }

  async checkHealth() {
    try {
      const res = await fetch(`${this.urlValue}/health`, { signal: AbortSignal.timeout(1500) })
      const body = res.ok ? await res.json() : {}
      this.online = body.ok === true
    } catch {
      this.online = false
    }
    if (!this.online) this.unavailable()
  }

  unavailable() {
    this.setStatus(this.labelUnavailableValue)
    if (this.hasRecordTarget) {
      this.recordTarget.disabled = true
      this.recordTarget.classList.add("cursor-not-allowed", "opacity-50")
    }
    this.clearTimers()
  }

  micProblem(error) {
    switch (error?.name) {
      case "NotAllowedError":
      case "SecurityError":
        return window.isSecureContext === false ? this.labelMicInsecureValue : this.labelMicDeniedValue
      case "NotFoundError":
      case "OverconstrainedError":
        return this.labelMicMissingValue
      default:
        return window.isSecureContext === false ? this.labelMicInsecureValue : this.labelMicDeniedValue
    }
  }

  togglePrelisten() {
    this.prelisten = this.prelistenTarget.checked
    localStorage.setItem(PRELISTEN_KEY, this.prelisten ? "1" : "0")
  }

  hasAudio() {
    return this.referenceClips().length > 0
  }

  referenceClips() {
    if (this.hasAudioPartsValue && this.audioPartsValue.length > 0) return this.audioPartsValue
    if (this.hasAudioUrlValue && this.audioUrlValue.length > 0) {
      return [{ url: this.audioUrlValue, stop_ms: this.audioStopValue }]
    }
    return []
  }

  async playAudio() {
    for (const clip of this.referenceClips()) await this.playClip(clip)
  }

  playClip(clip) {
    return new Promise((resolve) => {
      const audio = new Audio(clip.url)
      let settled = false
      const done = () => {
        if (settled) return
        settled = true
        audio.pause()
        resolve()
      }

      const stop = Number(clip.stop_ms) || 0
      if (stop > 0) {
        const limit = stop / 1000
        audio.addEventListener("timeupdate", () => {
          if (audio.currentTime >= limit) done()
        })
        this.clipTimer = setTimeout(done, stop + REFERENCE_GRACE_MS)
      }
      audio.onended = done
      audio.onerror = done
      audio.play().catch(done)
    })
  }

  clearTimers() {
    clearTimeout(this.retryTimer)
  }

  async toggle() {
    if (this.recording) return this.requestStop()
    if (this.prelisten && this.hasAudio() && this.mode === "word") {
      await this.playAudio()
      this.retryTimer = setTimeout(() => this.start(), 400)
      return
    }
    await this.start()
  }

  requestStop() {
    if (!this.analyser || !this.spoke) return this.stop()

    const now = performance.now()
    if (now - this.lastLoud < 150) {
      this.pendingStop = true
      this.stopDeadline = now + 600
      return
    }
    this.stop()
  }

  async start() {
    if (this.recording) return
    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    } catch (error) {
      this.setStatus(this.micProblem(error))
      this.clearTimers()
      return
    }
    this.chunks = []
    this.pendingStop = false

    this.recorder = new MediaRecorder(this.stream)
    this.recorder.ondataavailable = (e) => e.data.size && this.chunks.push(e.data)
    this.recorder.onstop = () => this.grade()
    this.recorder.start()
    this.recording = true
    this.recordTarget.textContent = this.labelListeningValue
    this.recordTarget.classList.add("bg-red-500", "text-white")
    this.setStatus(this.mode === "drill" ? this.drillPrompt() : this.labelRecordingValue)
    this.startMeter()
  }

  stop() {
    if (!this.recording) return
    this.recording = false
    this.teardownMeter()
    this.recorder?.stop()
    this.stream?.getTracks().forEach((t) => t.stop())
    this.recordTarget.textContent = this.labelRecordValue
    this.recordTarget.classList.remove("bg-red-500", "text-white")
  }

  startMeter() {
    this.meterRan = false
    try {
      this.audioCtx = new (window.AudioContext || window.webkitAudioContext)()
      const source = this.audioCtx.createMediaStreamSource(this.stream)
      this.analyser = this.audioCtx.createAnalyser()
      this.analyser.fftSize = 1024
      source.connect(this.analyser)
      this.buf = new Float32Array(this.analyser.fftSize)
      this.startedAt = performance.now()
      this.lastLoud = this.startedAt
      this.spoke = false
      this.meterRan = true
      this.meter = setInterval(() => this.tick(), 60)
    } catch {
      this.maxTimer = setTimeout(() => this.stop(), this.maxMsValue)
    }
  }

  tick() {
    if (!this.analyser) return
    this.analyser.getFloatTimeDomainData(this.buf)
    let sum = 0
    for (let i = 0; i < this.buf.length; i++) sum += this.buf[i] * this.buf[i]
    const rms = Math.sqrt(sum / this.buf.length)
    const now = performance.now()
    if (rms > SPEECH_RMS) {
      this.spoke = true
      this.lastLoud = now
    }
    const silentFor = now - this.lastLoud
    const elapsed = now - this.startedAt
    if (this.pendingStop && (silentFor > 180 || now > this.stopDeadline)) return this.stop()
    if ((this.spoke && silentFor > this.silenceMsValue) || elapsed > this.maxMsValue) {
      this.stop()
    }
  }

  teardownMeter() {
    clearInterval(this.meter)
    clearTimeout(this.maxTimer)
    this.analyser = null
    if (this.audioCtx) {
      this.audioCtx.close().catch(() => {})
      this.audioCtx = null
    }
  }

  currentExpected() {
    return this.expectedValue
  }

  async grade() {
    if (this.meterRan && !this.spoke) {
      this.setStatus(this.labelSilenceValue)
      return
    }
    this.setStatus(this.labelGradingValue)
    let wav
    try {
      wav = await toWav(new Blob(this.chunks, { type: this.recorder.mimeType || "audio/webm" }))
    } catch {
      this.setStatus(this.labelErrorValue)
      return
    }
    const expected = this.currentExpected()
    const form = new FormData()
    form.append("audio", wav, "utterance.wav")
    form.append("tonal", this.tonalValue ? "true" : "false")
    form.append("expected", JSON.stringify(expected))
    form.append("text", expected.map((s) => s.char).join(""))
    if (this.hasLexemeIdValue) form.append("lexeme_id", this.lexemeIdValue)
    try {
      const headers = {}
      const token = this.csrfToken()
      if (token) headers["X-CSRF-Token"] = token
      const res = await fetch(`${this.urlValue}/grade`, { method: "POST", body: form, headers })
      if (!res.ok) {
        if (res.status === 503) return this.unavailable()
        if (res.status === 422) {
          this.setStatus(this.labelSilenceValue)
          return
        }
        this.setStatus(this.labelErrorValue)
        return
      }
      this.handleResult(await res.json())
    } catch {
      this.setStatus(this.labelNetworkValue)
    }
  }

  handleResult(result) {
    this.setStatus("")
    if (this.mode === "drill") return this.handleDrillResult(result)

    this.renderWord(result)
    if (this.allGreen(result)) return this.finish()

    const wrong = result.syllables.map((s, i) => (s && s.level === "green" ? -1 : i)).filter((i) => i >= 0)
    if (this.expectedValue.length > 1 && wrong.length > 0) return this.enterDrill(wrong)
    this.retryWord()
  }

  allGreen(result) {
    const list = result.syllables || []
    return list.length > 0 && list.every((s) => s && s.level === "green")
  }

  retryWord() {
    this.setStatus(this.labelRetryValue)
  }

  enterDrill(wrongIndices) {
    this.mode = "drill"
    this.drillQueue = wrongIndices
    this.drillCursor = 0
    this.drillTries = 0
    this.startDrillStep()
  }

  startDrillStep() {
    if (this.drillCursor >= this.drillQueue.length) return this.finish()
    this.drillIndex = this.drillQueue[this.drillCursor]
    this.drillTries = 0
    this.highlightDrill()
    this.setStatus(this.drillPrompt())
  }

  handleDrillResult(result) {
    this.renderWord(result)
    this.highlightDrill()
    const syllable = result.syllables[this.drillIndex]
    if (syllable && syllable.level === "green") {
      this.drillCursor += 1
      this.startDrillStep()
      return
    }
    this.drillTries += 1
    if (this.drillTries >= MAX_DRILL_TRIES) {
      this.setStatus(this.labelDrillSkipValue)
      this.drillCursor += 1
      this.retryTimer = setTimeout(() => this.startDrillStep(), 1200)
    }
  }

  drillPrompt() {
    const target = this.expectedValue[this.drillIndex]
    return `${this.labelDrillValue}: ${target.char} (${target.pinyin})`
  }

  finish() {
    this.mode = "word"
  }

  highlightDrill() {
    this.syllableTargets.forEach((el, i) => {
      el.classList.toggle("ring-2", i === this.drillIndex)
      el.classList.toggle("ring-amber-500", i === this.drillIndex)
    })
  }

  paint(el, syllable) {
    const fill = el.querySelector("[data-role=fill]")
    const score = el.querySelector("[data-role=score]")
    const parts = el.querySelector("[data-role=parts]")

    el.style.borderColor = ""
    if (parts) parts.replaceChildren()
    if (!syllable || syllable.overall == null) {
      if (fill) fill.style.height = "0"
      if (score) score.textContent = ""
      return
    }

    const color = LEVELS[syllable.level] || LEVELS.gray
    el.style.borderColor = color
    if (fill) {
      fill.style.height = `${Math.max(4, syllable.fill || 0)}%`
      fill.style.backgroundColor = color
      fill.style.opacity = syllable.level === "dark" ? "0.35" : "0.22"
    }
    if (score) {
      score.textContent = syllable.rejected ? "?" : syllable.overall
      score.style.color = color
    }
    if (parts) this.paintBars(parts, syllable.parts || [])
  }

  paintBars(container, parts) {
    const ordered = PART_ORDER.map((id) => parts.find((p) => p.id === id)).filter(Boolean)

    ordered.forEach((part) => {
      const bar = document.createElement("span")
      bar.className = "w-1 rounded-sm"
      bar.style.height = part.score == null ? "2px" : `${Math.max(2, Math.round(part.score * 0.12))}px`
      bar.style.backgroundColor = LEVELS[part.level] || LEVELS.gray
      bar.style.opacity = part.score == null ? "0.35" : "1"
      bar.title = `${part.label}${part.zhuyin ? ` ${part.zhuyin}` : ""}: ${part.score ?? "—"}`
      container.appendChild(bar)
    })
  }

  renderWord(result) {
    this.syllableTargets.forEach((el, i) => this.paint(el, result.syllables[i]))
    this.lastResult = result
    this.renderDetails(result.syllables || [])
  }

  renderDetails(syllables) {
    if (!this.hasDetailTarget) return
    this.detailTarget.replaceChildren(...syllables.filter(Boolean).map((s) => this.detailCard(s)))
  }

  detailCard(syllable) {
    const box = document.createElement("section")
    box.className = "space-y-3 rounded-2xl border border-border bg-card p-4"

    box.appendChild(this.detailHeader(syllable))

    if (syllable.unavailable) {
      box.appendChild(this.note(this.labelNoTemplateValue))
      return box
    }

    if (syllable.contour) box.appendChild(this.toneChart(syllable))
    box.appendChild(this.partsGrid(syllable))

    const worst = (syllable.parts || [])
      .filter((p) => p.problem)
      .sort((a, b) => (a.score ?? 101) - (b.score ?? 101))[0]
    if (worst) box.appendChild(this.fixBlock(worst))
    ;(syllable.advisories || []).forEach((a) => box.appendChild(this.note(a.note)))
    if (syllable.diagnostics) box.appendChild(this.diagnosticsBlock(syllable))

    return box
  }

  diagnosticsBlock(syllable) {
    const box = document.createElement("details")
    box.className = "mt-1 text-2xs text-muted-foreground/70"

    const summary = document.createElement("summary")
    summary.className = "cursor-pointer select-none opacity-60 hover:opacity-100"
    summary.textContent = this.labelDetailsValue || "Details"
    box.appendChild(summary)

    const pre = document.createElement("pre")
    pre.className = "mt-2 overflow-x-auto whitespace-pre font-mono leading-snug"
    pre.textContent = this.imprint(syllable)

    const row = document.createElement("div")
    row.className = "mt-2 flex items-start gap-2"
    row.appendChild(pre)
    row.appendChild(this.copyButton(pre))
    box.appendChild(row)

    return box
  }

  copyButton(source) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "shrink-0 rounded border border-border px-1.5 py-0.5 opacity-50 transition hover:opacity-100"
    button.textContent = "⧉"
    button.title = this.labelCopyValue || "Copy"
    button.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(source.textContent)
        button.textContent = "✓"
      } catch {
        button.textContent = "✗"
      }
      setTimeout(() => (button.textContent = "⧉"), 1200)
    })
    return button
  }

  voiceLine(voice, n) {
    if (!voice || !voice.calibrated) return "Ω 0"

    const [low, mid, high] = voice.f0 || []
    return (
      `Ω ${voice.tone ? "2" : "1"} ${n(low, 0)}·${n(mid, 0)}·${n(high, 0)}` +
      ` ${n(voice.f3, 0)}·${n(voice.warp, 2)} ${voice.tones}/4` +
      ` ${voice.span == null ? "—" : n(voice.span, 1)}·${voice.excursion == null ? "—" : n(voice.excursion, 1)}` +
      ` ${voice.frames}/${voice.attempts}`
    )
  }

  imprint(syllable) {
    const { voice, signal, template, axes, fields } = syllable.diagnostics
    const n = (v, d) => {
      if (v == null) return "—"
      const x = Number(v)
      const digits = d != null ? d : Math.abs(x) >= 10 ? 0 : Math.abs(x) >= 1 ? 1 : 2
      return x
        .toFixed(digits)
        .replace(/(\.\d*?)0+$/, "$1")
        .replace(/\.$/, "")
        .replace("-", "−")
    }
    const sgn = (v) => (v == null ? "—" : (v < 0 ? "−" : "+") + Math.abs(v).toFixed(2))

    const head =
      `${syllable.char || ""}/${syllable.key} ⟦${syllable.overall ?? "—"}⟧${LEVEL_MARK[syllable.level] || "?"}` +
      `  Σ ${n(signal.duration_ms, 0)}/${n(signal.voiced_ms, 0)}/${n(signal.f0_ref_hz, 0)}${signal.f0_folded ? "^" : ""}` +
      `${signal.register == null ? "" : `/${sgn(signal.register)}`}` +
      `  q7${signal.vot_ms == null ? "—" : n(signal.vot_ms, 0)}${signal.vot_reliable ? "+" : "-"}` +
      `  τ${STYLE_MARK[template.style] || "s?"}·${template.tokens}/${template.speakers}·${CONF_MARK[template.confidence] || "?"}`

    const axisLine =
      "Α " +
      axes
        .map((a) => `${AXIS_MARK[a.id] || a.id[0].toUpperCase()}${sgn(a.z)}⟨${a.score}⟩${this.codeTag(a.code)}`)
        .join(" ")

    const rows = fields
      .filter((f) => f.z != null)
      .sort((a, b) => Math.abs(b.z) - Math.abs(a.z))
      .slice(0, 8)
      .map((f) => `${FIELD_MARK[f.field] || f.field.slice(0, 3)} ${n(f.value)}|${n(f.norm)}±${n(f.sigma)} ${sgn(f.z)}`)

    const lines = [this.voiceLine(voice, n), head, axisLine]
    const curve = syllable.contour && this.sparkPair(syllable.contour.curve, syllable.contour.reference)
    if (curve) lines.push(`Κ ε${curve[0]}\n  ρ${curve[1]}`)
    if (rows.length) lines.push("Φ " + rows.join("  "))

    return lines.join("\n")
  }

  codeTag(code) {
    if (!code) return "·"
    if (code.endsWith(".ok")) return "·"
    return CODE_MARK[code] || code.split(".").pop().slice(0, 4)
  }

  sparkPair(mine, reference) {
    if (!mine || !reference || !mine.length) return null
    const all = mine.concat(reference)
    const lo = Math.min(...all)
    const span = Math.max(...all) - lo || 1
    const draw = (v) => BARS[Math.min(BARS.length - 1, Math.max(0, Math.round(((v - lo) / span) * (BARS.length - 1))))]
    return [mine.map(draw).join(""), reference.map(draw).join("")]
  }

  detailHeader(syllable) {
    const row = document.createElement("div")
    row.className = "flex items-baseline justify-between gap-3"

    const left = document.createElement("div")
    left.className = "flex items-baseline gap-2"
    left.appendChild(this.span(syllable.char, "text-2xl", { lang: "zh-TW" }))
    left.appendChild(this.span(syllable.zhuyin, "text-sm font-medium"))
    left.appendChild(this.span(syllable.pinyin, "pinyin text-xs text-muted-foreground"))
    row.appendChild(left)

    const right = document.createElement("div")
    right.className = "text-right"
    const score = this.span(syllable.overall == null ? "—" : String(syllable.overall), "text-xl font-bold tabular-nums")
    score.style.color = LEVELS[syllable.level] || LEVELS.gray
    right.appendChild(score)
    const aside = syllable.rejected ? this.labelNotRecognizedValue : syllable.sounded_like
    if (aside) right.appendChild(this.span(aside, "block text-2xs text-muted-foreground"))
    row.appendChild(right)

    return row
  }

  partsGrid(syllable) {
    const wrap = document.createElement("div")
    wrap.className = "space-y-1.5"
    wrap.appendChild(this.span(this.labelPartsTitleValue, "block text-2xs uppercase tracking-wide text-muted-foreground"))

    const grid = document.createElement("div")
    grid.className = "grid grid-cols-4 gap-1.5"

    const parts = (syllable.parts || []).slice().sort((a, b) => PART_ORDER.indexOf(a.id) - PART_ORDER.indexOf(b.id))
    parts.forEach((part) => grid.appendChild(this.partCell(part)))
    wrap.appendChild(grid)
    return wrap
  }

  partCell(part) {
    const cell = document.createElement("div")
    const color = LEVELS[part.level] || LEVELS.gray
    cell.className = "relative overflow-hidden rounded-lg border px-1.5 py-1.5 text-center"
    cell.style.borderColor = part.level === "none" ? "" : color
    cell.title = [part.label, part.ipa && `/${part.ipa}/`, part.cue].filter(Boolean).join(" · ")

    if (part.score != null) {
      const fill = document.createElement("div")
      fill.className = "pointer-events-none absolute inset-x-0 bottom-0"
      fill.style.height = `${Math.max(3, part.score)}%`
      fill.style.backgroundColor = color
      fill.style.opacity = part.level === "dark" ? "0.35" : "0.18"
      cell.appendChild(fill)
    }

    const inner = document.createElement("div")
    inner.className = "relative space-y-0.5"
    inner.appendChild(this.span(this.partTitle(part), "block text-3xs uppercase tracking-wide text-muted-foreground"))
    inner.appendChild(this.span(part.zhuyin || "—", "block text-base font-semibold", { lang: "zh-TW" }))

    if (part.score == null) {
      const why = part.level === "none" ? this.labelNoPartValue : this.labelNotMeasuredValue
      inner.appendChild(this.span(why, "block text-3xs text-muted-foreground"))
    } else {
      const line = this.span(String(part.score), "block text-sm font-bold tabular-nums")
      line.style.color = color
      inner.appendChild(line)
      inner.appendChild(
        this.span(this.labelWeightValue.replace("%{percent}", part.weight), "block text-3xs text-muted-foreground"),
      )
    }

    cell.appendChild(inner)
    return cell
  }

  partTitle(part) {
    const sound = part.id === "tone" ? [part.zhuyin, part.pinyin] : [part.zhuyin, part.ipa && `/${part.ipa}/`]
    return [part.label, ...sound.filter(Boolean)].join(" ")
  }

  fixBlock(part) {
    const box = document.createElement("div")
    box.className = "space-y-1 rounded-lg bg-muted/60 px-3 py-2"
    const head = document.createElement("div")
    head.className = "flex items-baseline gap-2 text-2xs uppercase tracking-wide text-muted-foreground"
    head.appendChild(this.span(this.labelFixTitleValue, ""))
    head.appendChild(this.span(this.partTitle(part), "font-semibold text-foreground", { lang: "zh-TW" }))
    box.appendChild(head)
    box.appendChild(this.span(part.problem, "block text-sm font-medium"))
    if (part.advice) box.appendChild(this.span(part.advice, "block text-sm"))
    if (part.cue) box.appendChild(this.span(part.cue, "block text-xs text-muted-foreground"))
    return box
  }

  note(text) {
    return this.span(text, "block text-xs text-muted-foreground")
  }

  toneChart(syllable) {
    const { curve, reference, sigma } = syllable.contour
    const w = 260
    const h = 88
    const pad = 6
    const left = 16

    const lows = reference.map((v, i) => v - (sigma[i] || 0))
    const highs = reference.map((v, i) => v + (sigma[i] || 0))
    const min = Math.min(...curve, ...lows) - 0.5
    const max = Math.max(...curve, ...highs) + 0.5
    const span = Math.max(max - min, 2)

    const x = (i, n) => left + (i * (w - left - pad)) / (n - 1)
    const y = (v) => pad + (h - 2 * pad) * (1 - (v - min) / span)
    const path = (values) => values.map((v, i) => `${i ? "L" : "M"}${x(i, values.length).toFixed(1)},${y(v).toFixed(1)}`).join(" ")

    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg")
    svg.setAttribute("viewBox", `0 0 ${w} ${h}`)
    svg.setAttribute("class", "w-full")
    svg.setAttribute("role", "img")

    const bandPoints = [
      ...highs.map((v, i) => `${x(i, highs.length).toFixed(1)},${y(v).toFixed(1)}`),
      ...lows.map((v, i) => `${x(i, lows.length).toFixed(1)},${y(v).toFixed(1)}`).reverse(),
    ].join(" ")

    const step = span > 14 ? 4 : span > 7 ? 2 : 1
    for (let v = Math.ceil(min / step) * step; v <= max; v += step) {
      svg.appendChild(
        this.svgNode("line", {
          x1: left, x2: w - pad, y1: y(v).toFixed(1), y2: y(v).toFixed(1),
          stroke: "currentColor", "stroke-opacity": v === 0 ? "0.25" : "0.08", "stroke-width": "1",
        }),
      )
      const tick = this.svgNode("text", { x: 2, y: (y(v) + 3).toFixed(1), "font-size": "8", fill: "currentColor", "fill-opacity": "0.45" })
      tick.textContent = v > 0 ? `+${v}` : `${v}`
      svg.appendChild(tick)
    }

    svg.appendChild(this.svgNode("polygon", { points: bandPoints, fill: "currentColor", "fill-opacity": "0.12" }))
    svg.appendChild(
      this.svgNode("path", {
        d: path(reference),
        fill: "none",
        stroke: "currentColor",
        "stroke-width": "1.5",
        "stroke-dasharray": "4 3",
        "stroke-opacity": "0.65",
      }),
    )
    svg.appendChild(
      this.svgNode("path", {
        d: path(curve),
        fill: "none",
        stroke: LEVELS[this.toneLevel(syllable)] || LEVELS.gray,
        "stroke-width": "2.5",
        "stroke-linecap": "round",
        "stroke-linejoin": "round",
      }),
    )

    const wrap = document.createElement("div")
    wrap.className = "space-y-1 text-muted-foreground"
    wrap.appendChild(svg)
    wrap.appendChild(this.span(this.labelChartHintValue, "block text-3xs"))
    return wrap
  }

  toneLevel(syllable) {
    return (syllable.parts || []).find((p) => p.id === "tone")?.level || syllable.level
  }

  svgNode(name, attrs) {
    const node = document.createElementNS("http://www.w3.org/2000/svg", name)
    Object.entries(attrs).forEach(([k, v]) => node.setAttribute(k, v))
    return node
  }

  span(text, className, attrs = {}) {
    const el = document.createElement("span")
    el.className = className
    el.textContent = text ?? ""
    Object.entries(attrs).forEach(([k, v]) => el.setAttribute(k, v))
    return el
  }

  setStatus(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }
}
