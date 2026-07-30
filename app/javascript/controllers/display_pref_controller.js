import { Controller } from "@hotwired/stimulus"

const YEAR = 60 * 60 * 24 * 365

export default class extends Controller {
  static values = { name: String, css: String, on: String, off: String, invert: Boolean }

  connect() {
    this.reflect()
  }

  toggle() {
    const present = document.documentElement.classList.toggle(this.cssValue)
    document.cookie = `${this.nameValue}=${present ? this.onValue : this.offValue}; path=/; max-age=${YEAR}; samesite=lax`
    document
      .querySelectorAll(`[data-display-pref-name-value="${this.nameValue}"]`)
      .forEach((element) => element.dispatchEvent(new CustomEvent("display-pref:reflect")))
    document.dispatchEvent(new CustomEvent("display-pref:changed", { detail: { name: this.nameValue } }))
  }

  reflect() {
    const present = document.documentElement.classList.contains(this.cssValue)
    this.element.setAttribute("aria-pressed", String(this.invertValue ? !present : present))
  }
}
