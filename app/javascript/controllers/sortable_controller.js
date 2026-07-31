import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]
  static values = { url: String, param: { type: String, default: "order" } }

  connect() {
    this.dragging = null
    this.pending = null
  }

  disconnect() {
    this.release()
    if (this.pending) clearTimeout(this.pending)
  }

  start(event) {
    if (event.button !== undefined && event.button !== 0) return

    const item = event.target.closest("[data-sortable-target='item']")
    if (!item) return

    event.preventDefault()
    this.dragging = item
    this.pointerId = event.pointerId
    this.offsetY = event.clientY - item.getBoundingClientRect().top
    item.setPointerCapture(event.pointerId)
    item.classList.add("sortable-dragging")
  }

  move(event) {
    if (!this.dragging) return

    event.preventDefault()
    const over = this.itemAt(event.clientY)
    if (!over || over === this.dragging) return

    const before = over.getBoundingClientRect().top + over.offsetHeight / 2
    if (event.clientY < before) over.before(this.dragging)
    else over.after(this.dragging)
  }

  end() {
    if (!this.dragging) return

    this.release()
    this.schedule()
  }

  moveUp(event) {
    const item = event.target.closest("[data-sortable-target='item']")
    const previous = item?.previousElementSibling
    if (!previous) return

    previous.before(item)
    this.schedule()
  }

  moveDown(event) {
    const item = event.target.closest("[data-sortable-target='item']")
    const next = item?.nextElementSibling
    if (!next) return

    next.after(item)
    this.schedule()
  }

  itemAt(clientY) {
    return this.itemTargets.find((item) => {
      const box = item.getBoundingClientRect()
      return clientY >= box.top && clientY <= box.bottom
    })
  }

  release() {
    if (!this.dragging) return

    this.dragging.classList.remove("sortable-dragging")
    try {
      this.dragging.releasePointerCapture(this.pointerId)
    } catch {}
    this.dragging = null
  }

  schedule() {
    if (this.pending) clearTimeout(this.pending)
    this.pending = setTimeout(() => this.persist(), 300)
  }

  async persist() {
    this.pending = null
    if (!this.urlValue) return

    const body = new URLSearchParams()
    for (const item of this.itemTargets) body.append(`${this.paramValue}[]`, item.dataset.sortableId)

    try {
      await fetch(this.urlValue, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded", "X-CSRF-Token": this.csrf() },
        body,
      })
    } catch {}
  }

  csrf() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
