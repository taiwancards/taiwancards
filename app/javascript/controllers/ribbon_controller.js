import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    const current = this.element.querySelector("[aria-current='page']");
    if (!current || this.element.scrollWidth <= this.element.clientWidth)
      return;
    const start =
      current.getBoundingClientRect().left -
      this.element.getBoundingClientRect().left +
      this.element.scrollLeft;
    const centered =
      start - (this.element.clientWidth - current.offsetWidth) / 2;
    this.element.scrollLeft = Math.max(0, centered);
  }
}
