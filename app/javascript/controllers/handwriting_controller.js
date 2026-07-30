import { Controller } from "@hotwired/stimulus"
import HanziLookup from "hanzi-lookup"

let dataPromise = null

function loadData(url) {
  if (!dataPromise) {
    dataPromise = new Promise((resolve, reject) => {
      HanziLookup.init("mmah", url, (success) => (success ? resolve(true) : reject(new Error("data"))))
    })
  }
  return dataPromise
}

export default class extends Controller {
  static targets = ["canvas", "results", "status"]
  static values = { url: String, base: String, emit: Boolean, limit: { type: Number, default: 12 } }

  connect() {
    this.strokes = []
    this.current = null
    this.ctx = this.canvasTarget.getContext("2d")
    this.resize()
    this.drawGuides()
    this.pointerDown = (e) => this.start(e)
    this.pointerMove = (e) => this.move(e)
    this.pointerUp = (e) => this.end(e)
    this.canvasTarget.addEventListener("pointerdown", this.pointerDown)
    this.canvasTarget.addEventListener("pointermove", this.pointerMove)
    this.canvasTarget.addEventListener("pointerup", this.pointerUp)
    this.canvasTarget.addEventListener("pointerleave", this.pointerUp)
    this.observer = new ResizeObserver(() => this.refit())
    this.observer.observe(this.canvasTarget)
    this.setStatus(this.statusTarget?.dataset.loading || "…")
    loadData(this.urlValue).then(() => this.setStatus("")).catch(() => this.setStatus(this.statusTarget?.dataset.failed || "!"))
  }

  disconnect() {
    this.canvasTarget.removeEventListener("pointerdown", this.pointerDown)
    this.canvasTarget.removeEventListener("pointermove", this.pointerMove)
    this.canvasTarget.removeEventListener("pointerup", this.pointerUp)
    this.canvasTarget.removeEventListener("pointerleave", this.pointerUp)
    this.observer.disconnect()
  }

  refit() {
    const side = this.canvasTarget.clientWidth
    if (!side || side === this.size) return

    this.resize()
    this.repaint()
  }

  resize() {
    const side = this.canvasTarget.clientWidth || this.canvasTarget.getBoundingClientRect().width
    if (!side) return

    const dpr = window.devicePixelRatio || 1
    this.canvasTarget.style.height = `${side}px`
    this.canvasTarget.width = side * dpr
    this.canvasTarget.height = side * dpr
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    this.size = side
  }

  point(event) {
    const rect = this.canvasTarget.getBoundingClientRect()
    return [event.clientX - rect.left, event.clientY - rect.top]
  }

  start(event) {
    event.preventDefault()
    this.canvasTarget.setPointerCapture(event.pointerId)
    this.current = [this.point(event)]
    const [x, y] = this.current[0]
    this.ctx.beginPath()
    this.ctx.moveTo(x, y)
  }

  move(event) {
    if (!this.current) return
    const [x, y] = this.point(event)
    this.current.push([x, y])
    this.ctx.lineTo(x, y)
    this.ctx.strokeStyle = "#10b981"
    this.ctx.lineWidth = 6
    this.ctx.lineCap = "round"
    this.ctx.lineJoin = "round"
    this.ctx.stroke()
  }

  end() {
    if (!this.current) return
    if (this.current.length > 1) {
      this.strokes.push(this.current)
      this.recognize()
    }
    this.current = null
  }

  recognize() {
    if (this.strokes.length === 0) return
    const analyzed = new HanziLookup.AnalyzedCharacter(this.strokes)
    new HanziLookup.Matcher("mmah").match(analyzed, this.limitValue, (matches) => this.render(matches))
  }

  render(matches) {
    this.resultsTarget.replaceChildren()
    matches.forEach((match) => {
      this.resultsTarget.appendChild(this.emitValue ? this.chip(match) : this.link(match))
    })
  }

  link(match) {
    const link = document.createElement("a")
    link.textContent = match.character
    link.href = `${this.baseValue}/${encodeURIComponent(match.character)}`
    link.lang = "zh-TW"
    link.className =
      "flex size-12 items-center justify-center rounded-lg border border-border text-2xl hover:bg-primary/15 hover:text-primary"
    return link
  }

  chip(match) {
    const chip = document.createElement("button")
    chip.type = "button"
    chip.textContent = match.character
    chip.lang = "zh-TW"
    chip.className =
      "flex size-10 items-center justify-center rounded-lg border border-border text-xl hover:bg-primary/15 hover:text-primary"
    chip.addEventListener("click", () => this.dispatch("pick", { detail: { character: match.character } }))
    return chip
  }

  undo() {
    this.strokes.pop()
    this.repaint()
    this.strokes.length ? this.recognize() : this.resultsTarget.replaceChildren()
  }

  clear() {
    this.strokes = []
    this.repaint()
    this.resultsTarget.replaceChildren()
  }

  repaint() {
    this.ctx.clearRect(0, 0, this.canvasTarget.width, this.canvasTarget.height)
    this.drawGuides()
    this.ctx.strokeStyle = "#10b981"
    this.ctx.lineWidth = 6
    this.ctx.lineCap = "round"
    this.ctx.lineJoin = "round"
    this.strokes.forEach((stroke) => {
      this.ctx.beginPath()
      stroke.forEach(([x, y], i) => (i === 0 ? this.ctx.moveTo(x, y) : this.ctx.lineTo(x, y)))
      this.ctx.stroke()
    })
  }

  drawGuides() {
    const s = this.size
    this.ctx.save()
    this.ctx.strokeStyle = "rgba(120,120,120,0.25)"
    this.ctx.lineWidth = 1
    this.ctx.setLineDash([6, 6])
    this.ctx.beginPath()
    this.ctx.moveTo(s / 2, 0); this.ctx.lineTo(s / 2, s)
    this.ctx.moveTo(0, s / 2); this.ctx.lineTo(s, s / 2)
    this.ctx.stroke()
    this.ctx.restore()
  }

  setStatus(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }
}
