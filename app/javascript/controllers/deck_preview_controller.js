import { Controller } from "@hotwired/stimulus"

const FOREIGN = 0
const UNLISTED = 1
const CANDIDATE = 2
const CHUNK = 60

export default class extends Controller {
  static targets = [
    "data",
    "text",
    "sentinel",
    "selection",
    "count",
    "capNotice",
    "level",
    "skipKnown",
    "skipInDecks",
    "maxFreq",
    "list",
    "panel",
    "panelEmpty",
    "panelBody",
    "panelText",
    "panelKind",
    "panelReading",
    "panelMeaning",
    "panelTocfl",
    "panelTbcl",
    "panelFreq",
    "panelScore",
    "panelState",
    "panelToggle",
  ]
  static values = {
    limit: Number,
    labelInclude: String,
    labelExclude: String,
    labelKnown: String,
    labelInDeck: String,
    labelFresh: String,
    labelNone: String,
  }

  connect() {
    const payload = JSON.parse(this.dataTarget.textContent)
    this.lines = payload.lines
    this.candidates = payload.candidates
    this.spans = new Map()
    this.selected = new Set()
    this.rendered = 0

    this.applyFilters()
    this.renderChunk()
    this.observe()
  }

  disconnect() {
    this.observer?.disconnect()
  }

  observe() {
    if (!this.hasSentinelTarget) return

    this.observer = new IntersectionObserver((entries) => {
      if (entries.some((entry) => entry.isIntersecting)) this.renderChunk()
    })
    this.observer.observe(this.sentinelTarget)
  }

  renderChunk() {
    if (this.rendered >= this.lines.length) {
      this.observer?.disconnect()
      if (this.hasSentinelTarget) this.sentinelTarget.remove()
      return
    }

    const fragment = document.createDocumentFragment()
    const stop = Math.min(this.rendered + CHUNK, this.lines.length)
    for (let index = this.rendered; index < stop; index++) {
      fragment.appendChild(this.buildLine(this.lines[index]))
    }
    this.textTarget.appendChild(fragment)
    this.rendered = stop
  }

  buildLine(tokens) {
    const line = document.createElement("p")
    line.className = "preview-line"
    for (const token of tokens) line.appendChild(this.buildToken(token))
    if (tokens.length === 0) line.appendChild(document.createElement("br"))
    return line
  }

  buildToken(token) {
    const span = document.createElement("span")
    span.textContent = token.t

    if (token.k === FOREIGN) {
      span.className = "tok tok-foreign"
      return span
    }
    if (token.k === UNLISTED) {
      span.className = "tok tok-unlisted"
      span.title = token.t
      return span
    }

    const entry = this.candidates[token.w]
    span.className = "tok tok-word"
    span.dataset.w = token.w
    span.setAttribute("role", "button")
    span.setAttribute("tabindex", "0")
    if (entry.s) span.classList.add("tok-known")
    if (this.selected.has(token.w)) span.classList.add("tok-on")

    const bucket = this.spans.get(token.w)
    if (bucket) bucket.push(span)
    else this.spans.set(token.w, [span])

    return span
  }

  toggle(event) {
    const word = event.target.closest("[data-w]")
    if (!word) return

    this.flip(Number(word.dataset.w))
  }

  toggleByKey(event) {
    if (event.key !== "Enter" && event.key !== " ") return

    const word = event.target.closest("[data-w]")
    if (!word) return

    event.preventDefault()
    this.flip(Number(word.dataset.w))
  }

  flip(index) {
    if (Number.isNaN(index)) return

    if (this.selected.has(index)) this.selected.delete(index)
    else this.selected.add(index)

    this.paint(index)
    this.describe(index)
    this.sync()
  }

  toggleCurrent() {
    if (this.current === undefined) return

    this.flip(this.current)
  }

  describe(index) {
    const entry = this.candidates[index]
    if (!entry || !this.hasPanelBodyTarget) return

    this.current = index
    this.panelEmptyTarget.hidden = true
    this.panelBodyTarget.classList.remove("hidden")

    this.panelTextTarget.textContent = entry.t
    this.panelTextTarget.href = entry.u || "#"
    this.panelKindTarget.textContent = entry.k || ""
    this.panelReadingTarget.textContent = entry.r || ""
    this.panelMeaningTarget.textContent = entry.m || ""
    this.panelTocflTarget.textContent = entry.l || this.labelNoneValue
    this.panelTbclTarget.textContent = entry.b || this.labelNoneValue
    this.panelFreqTarget.textContent = entry.f || this.labelNoneValue
    this.panelScoreTarget.textContent = entry.c ?? this.labelNoneValue
    this.panelStateTarget.textContent = this.stateLabel(entry)
    this.panelToggleTarget.textContent = this.selected.has(index)
      ? this.labelExcludeValue
      : this.labelIncludeValue
  }

  stateLabel(entry) {
    if (entry.s) return this.labelKnownValue
    if (entry.d) return this.labelInDeckValue
    return this.labelFreshValue
  }

  applyFilters() {
    const level = this.hasLevelTarget ? this.levelTarget.value : ""
    const maxFreq = this.hasMaxFreqTarget ? Number(this.maxFreqTarget.value) : 0
    const skipKnown = this.hasSkipKnownTarget && this.skipKnownTarget.checked
    const skipInDecks = this.hasSkipInDecksTarget && this.skipInDecksTarget.checked

    this.selected = new Set()
    for (const entry of this.candidates) {
      if (skipKnown && entry.s) continue
      if (skipInDecks && entry.d) continue
      if (level && String(entry.l) !== level) continue
      if (maxFreq > 0 && entry.f && entry.f <= maxFreq) continue
      if (this.selected.size >= this.limitValue) break

      this.selected.add(entry.i)
    }

    this.repaintAll()
    this.sync()
  }

  selectAll() {
    this.selected = new Set(this.candidates.slice(0, this.limitValue).map((entry) => entry.i))
    this.repaintAll()
    this.sync()
  }

  selectNone() {
    this.selected = new Set()
    this.repaintAll()
    this.sync()
  }

  paint(index) {
    const on = this.selected.has(index)
    for (const span of this.spans.get(index) || []) span.classList.toggle("tok-on", on)
    const row = this.hasListTarget ? this.listTarget.querySelector(`[data-row="${index}"]`) : null
    if (row) row.classList.toggle("row-on", on)
    const box = row?.querySelector("input[type=checkbox]")
    if (box) box.checked = on
  }

  repaintAll() {
    for (const index of this.spans.keys()) this.paint(index)
    if (!this.hasListTarget) return

    for (const row of this.listTarget.querySelectorAll("[data-row]")) {
      const index = Number(row.dataset.row)
      const on = this.selected.has(index)
      row.classList.toggle("row-on", on)
      const box = row.querySelector("input[type=checkbox]")
      if (box) box.checked = on
    }
  }

  toggleRow(event) {
    const row = event.target.closest("[data-row]")
    if (!row) return

    this.flip(Number(row.dataset.row))
  }

  sync() {
    if (this.current !== undefined && this.hasPanelToggleTarget) {
      this.panelToggleTarget.textContent = this.selected.has(this.current)
        ? this.labelExcludeValue
        : this.labelIncludeValue
    }
    this.selectionTarget.value = this.encode()
    if (this.hasCountTarget) this.countTarget.textContent = this.selected.size
    if (this.hasCapNoticeTarget) {
      this.capNoticeTarget.hidden = this.selected.size < this.limitValue
    }
  }

  encode() {
    const ids = []
    for (const index of this.selected) {
      const entry = this.candidates[index]
      if (entry) ids.push(entry.id.toString(36))
    }
    return ids.join(",")
  }
}
