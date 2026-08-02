import { Controller } from "@hotwired/stimulus"

const RADICALS = {
  a: "日", b: "月", c: "金", d: "木", e: "水", f: "火", g: "土", h: "竹", i: "戈",
  j: "十", k: "大", l: "中", m: "一", n: "弓", o: "人", p: "心", q: "手", r: "口",
  s: "尸", t: "廿", u: "山", v: "女", w: "田", x: "難", y: "卜", z: "重",
}

export default class extends Controller {
  static targets = ["output", "code", "radicals", "candidates", "key"]
  static values = { url: String }

  connect() {
    this.buffer = ""
    this.lookup = {}
    this.codes = []
    fetch(this.urlValue)
      .then((r) => r.json())
      .then((data) => {
        this.lookup = data
        this.codes = Object.keys(data).sort((a, b) => a.length - b.length || (a < b ? -1 : 1))
        this.refresh()
      })
  }

  keydown(event) {
    const key = event.key

    if (/^[a-zA-Z]$/.test(key)) {
      event.preventDefault()
      this.type(key.toLowerCase())
    } else if (key === " " && this.buffer) {
      event.preventDefault()
      this.pick(0)
    } else if (/^[1-9]$/.test(key) && this.candidates().length) {
      event.preventDefault()
      this.pick(Number(key) - 1)
    } else if (key === "Backspace" && this.buffer) {
      event.preventDefault()
      this.erase()
    } else if (key === "Escape") {
      this.reset()
    }
  }

  beforeinput(event) {
    if (!event.cancelable) return
    const data = event.data || ""

    if (event.inputType === "deleteContentBackward" && this.buffer) {
      event.preventDefault()
      this.erase()
    } else if (/^[a-zA-Z]$/.test(data)) {
      event.preventDefault()
      this.type(data.toLowerCase())
    } else if (data === " " && this.buffer) {
      event.preventDefault()
      this.pick(0)
    } else if (/^[1-9]$/.test(data) && this.candidates().length) {
      event.preventDefault()
      this.pick(Number(data) - 1)
    }
  }

  press(event) {
    this.type(event.currentTarget.dataset.key)
  }

  space() {
    if (this.buffer) this.pick(0)
  }

  backspace() {
    this.erase()
  }

  clear() {
    this.reset()
  }

  type(letter) {
    if (this.buffer.length < 5) this.buffer += letter
    this.flash(letter)
    this.refresh()
  }

  erase() {
    this.buffer = this.buffer.slice(0, -1)
    this.refresh()
  }

  reset() {
    this.buffer = ""
    this.refresh()
  }

  candidates() {
    if (!this.buffer) return []
    const exact = this.lookup[this.buffer] || []
    const seen = new Set(exact)
    const result = [...exact]
    for (const code of this.codes) {
      if (code.length <= this.buffer.length || !code.startsWith(this.buffer)) continue
      for (const char of this.lookup[code]) {
        if (!seen.has(char)) {
          seen.add(char)
          result.push(char)
        }
      }
      if (result.length >= 60) break
    }
    return result
  }

  pick(index) {
    const char = this.candidates()[index]
    if (!char) return
    this.insert(char)
    this.buffer = ""
    this.refresh()
  }

  choose(event) {
    this.pick(Number(event.currentTarget.dataset.index))
    if (!window.matchMedia("(pointer: coarse)").matches) this.outputTarget.focus()
  }

  insert(text) {
    const el = this.outputTarget
    const start = el.selectionStart ?? el.value.length
    const end = el.selectionEnd ?? el.value.length
    el.value = el.value.slice(0, start) + text + el.value.slice(end)
    const caret = start + text.length
    el.setSelectionRange(caret, caret)
  }

  refresh() {
    this.codeTarget.textContent = this.buffer
    this.radicalsTarget.textContent = this.buffer.split("").map((l) => RADICALS[l] || "").join("")
    this.candidatesTarget.replaceChildren()
    this.candidates().slice(0, 20).forEach((char, index) => {
      const chip = document.createElement("button")
      chip.type = "button"
      chip.lang = "zh-TW"
      chip.dataset.index = index
      chip.dataset.action = "cangjie#choose"
      chip.className = "flex items-center gap-1 rounded-lg border border-border px-2 py-1 text-xl hover:bg-primary/10"
      chip.innerHTML = `<span class="text-xs text-muted-foreground">${index + 1}</span>${char}`
      this.candidatesTarget.appendChild(chip)
    })
  }

  flash(letter) {
    const key = this.keyTargets.find((k) => k.dataset.key === letter)
    if (!key) return
    key.classList.add("bg-primary", "text-primary-foreground")
    setTimeout(() => key.classList.remove("bg-primary", "text-primary-foreground"), 150)
  }
}
