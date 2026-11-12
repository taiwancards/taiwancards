import { Controller } from "@hotwired/stimulus";
import { csrfToken } from "lib/csrf";

export default class extends Controller {
  static targets = ["item"];
  static values = { url: String, param: { type: String, default: "order" } };

  connect() {
    this.dragging = null;
    this.pending = null;
    this.saved = this.itemTargets;
  }

  disconnect() {
    this.release();
    if (!this.pending) return;

    clearTimeout(this.pending);
    this.persist({ keepalive: true });
  }

  start(event) {
    if (event.button !== undefined && event.button !== 0) return;

    const item = event.target.closest("[data-sortable-target='item']");
    if (!item) return;

    event.preventDefault();
    this.dragging = item;
    this.pointerId = event.pointerId;
    this.offsetY = event.clientY - item.getBoundingClientRect().top;
    item.setPointerCapture(event.pointerId);
    item.classList.add("sortable-dragging");
  }

  move(event) {
    if (!this.dragging) return;

    event.preventDefault();
    const over = this.itemAt(event.clientY);
    if (!over || over === this.dragging) return;

    const before = over.getBoundingClientRect().top + over.offsetHeight / 2;
    if (event.clientY < before) over.before(this.dragging);
    else over.after(this.dragging);
  }

  end() {
    if (!this.dragging) return;

    this.release();
    this.schedule();
  }

  moveUp(event) {
    const item = event.target.closest("[data-sortable-target='item']");
    const previous = item?.previousElementSibling;
    if (!previous) return;

    previous.before(item);
    this.schedule();
  }

  moveDown(event) {
    const item = event.target.closest("[data-sortable-target='item']");
    const next = item?.nextElementSibling;
    if (!next) return;

    next.after(item);
    this.schedule();
  }

  itemAt(clientY) {
    return this.itemTargets.find((item) => {
      const box = item.getBoundingClientRect();
      return clientY >= box.top && clientY <= box.bottom;
    });
  }

  release() {
    if (!this.dragging) return;

    this.dragging.classList.remove("sortable-dragging");
    try {
      this.dragging.releasePointerCapture(this.pointerId);
    } catch {}
    this.dragging = null;
  }

  schedule() {
    if (this.pending) clearTimeout(this.pending);
    this.pending = setTimeout(() => this.persist(), 300);
  }

  async persist({ keepalive = false } = {}) {
    this.pending = null;
    if (!this.urlValue) return;

    const order = this.itemTargets;
    const body = new URLSearchParams();
    for (const item of order)
      body.append(`${this.paramValue}[]`, item.dataset.sortableId);

    const response = await fetch(this.urlValue, {
      method: "POST",
      keepalive,
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": csrfToken(),
      },
      body,
    }).catch(() => null);

    if (response?.ok) {
      this.saved = order;
      return;
    }
    if (!this.pending && !this.dragging) this.restore(this.saved);
  }

  restore(order) {
    const current = this.itemTargets;
    if (
      order.length !== current.length ||
      !order.every((item) => current.includes(item))
    )
      return;

    const marks = current.map((item) => {
      const mark = document.createTextNode("");
      item.before(mark);
      return mark;
    });
    marks.forEach((mark, index) => mark.replaceWith(order[index]));
  }
}
