import { Controller } from "@hotwired/stimulus"

const GAP = 14
const PAD = 6
const EDGE = 12

export default class extends Controller {
  static targets = ["spotlight", "popover", "panel", "block", "hint", "forward"]
  static values = { anchor: String, blocking: String, awaitClick: String, interactive: String }

  connect() {
    this.place = this.place.bind(this)
    this.guard = this.guard.bind(this)

    window.addEventListener("resize", this.place)
    window.addEventListener("scroll", this.place, true)
    document.addEventListener("keydown", this.guard, true)
    document.addEventListener("click", this.place, true)

    const el = this.anchor
    if (el) {
      el.scrollIntoView({ behavior: "instant", block: "center" })
      this.watcher = new MutationObserver(this.place)
      this.watcher.observe(el, { attributes: true, childList: true, subtree: true })
    }

    this.place()
    requestAnimationFrame(this.place)
    this.settle = setTimeout(this.place, 300)
    document.fonts?.ready.then(this.place)
  }

  disconnect() {
    clearTimeout(this.settle)
    window.removeEventListener("resize", this.place)
    window.removeEventListener("scroll", this.place, true)
    document.removeEventListener("keydown", this.guard, true)
    document.removeEventListener("click", this.place, true)
    this.watcher?.disconnect()
  }

  get blocking() {
    return this.blockingValue === "true"
  }

  get awaitsClick() {
    return this.awaitClickValue === "true"
  }

  get interactive() {
    return this.interactiveValue === "true"
  }

  get anchor() {
    if (!this.anchorValue) return null

    return (
      [...document.querySelectorAll(`[data-tour="${this.anchorValue}"]`)].find((el) => {
        const box = el.getBoundingClientRect()
        return box.width > 0 && box.height > 0
      }) || null
    )
  }

  guard(event) {
    if (this.blocking && event.key === "Escape") {
      event.preventDefault()
      event.stopPropagation()
    }
  }

  reach(el) {
    const box = el.getBoundingClientRect()
    let { top, left, right, bottom } = box

    el.querySelectorAll("*").forEach((child) => {
      const rect = child.getBoundingClientRect()
      if (rect.width === 0 || rect.height === 0) return
      if (getComputedStyle(child).visibility === "hidden") return

      top = Math.min(top, rect.top)
      left = Math.min(left, rect.left)
      right = Math.max(right, rect.right)
      bottom = Math.max(bottom, rect.bottom)
    })

    return { top, left, right, bottom, width: right - left, height: bottom - top }
  }

  place() {
    const el = this.anchor
    const hole = el ? this.reach(el) : null

    this.guided = Boolean(hole) && this.interactive
    const handover = Boolean(hole) && this.awaitsClick

    if (this.hasHintTarget) this.hintTarget.classList.toggle("hidden", !this.guided)
    if (this.hasForwardTarget) this.forwardTarget.classList.toggle("hidden", handover)
    this.spotlightTarget.classList.toggle("intro-beacon", this.guided)

    this.frame(hole)
    if (!hole) return this.center()

    const spot = this.spotlightTarget.style
    spot.opacity = "1"
    spot.top = `${hole.top - PAD}px`
    spot.left = `${hole.left - PAD}px`
    spot.width = `${hole.width + PAD * 2}px`
    spot.height = `${hole.height + PAD * 2}px`

    const pop = this.popoverTarget
    const width = pop.offsetWidth
    const height = pop.offsetHeight

    let top = hole.bottom + GAP
    if (top + height > window.innerHeight - EDGE) {
      const above = hole.top - height - GAP
      top = above >= EDGE ? above : Math.max(EDGE, window.innerHeight - height - EDGE)
    }

    let left = hole.left + hole.width / 2 - width / 2
    left = Math.min(Math.max(EDGE, left), window.innerWidth - width - EDGE)

    pop.style.top = `${top}px`
    pop.style.left = `${left}px`
    pop.style.transform = ""
  }

  frame(hole) {
    const full = { top: 0, left: 0, right: window.innerWidth, bottom: window.innerHeight }
    const box = hole
      ? {
          top: Math.max(0, hole.top - PAD),
          left: Math.max(0, hole.left - PAD),
          right: Math.min(full.right, hole.right + PAD),
          bottom: Math.min(full.bottom, hole.bottom + PAD)
        }
      : { top: full.bottom, left: full.right, right: full.right, bottom: full.bottom }

    const sides = [
      { top: 0, left: 0, width: full.right, height: box.top },
      { top: box.bottom, left: 0, width: full.right, height: full.bottom - box.bottom },
      { top: box.top, left: 0, width: box.left, height: box.bottom - box.top },
      { top: box.top, left: box.right, width: full.right - box.right, height: box.bottom - box.top }
    ]

    this.panelTargets.forEach((panel, index) => {
      const side = sides[index]
      panel.style.top = `${Math.max(0, side.top)}px`
      panel.style.left = `${Math.max(0, side.left)}px`
      panel.style.width = `${Math.max(0, side.width)}px`
      panel.style.height = `${Math.max(0, side.height)}px`
    })

    const cover = this.blockTarget.style
    const sealed = !this.guided
    cover.display = sealed ? "block" : "none"
    if (!sealed) return

    cover.top = `${box.top}px`
    cover.left = `${box.left}px`
    cover.width = `${Math.max(0, box.right - box.left)}px`
    cover.height = `${Math.max(0, box.bottom - box.top)}px`
  }

  center() {
    const spot = this.spotlightTarget.style
    spot.opacity = "0"
    spot.width = "0px"
    spot.height = "0px"

    const pop = this.popoverTarget
    pop.style.top = "50%"
    pop.style.left = "50%"
    pop.style.transform = "translate(-50%, -50%)"
  }
}
