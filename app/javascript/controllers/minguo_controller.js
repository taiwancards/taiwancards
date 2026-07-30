import { Controller } from "@hotwired/stimulus"

const EPOCH = 1911

export default class extends Controller {
  static targets = ["gregorian", "minguo", "note"]

  connect() {
    this.fromGregorian()
  }

  fromGregorian() {
    const year = parseInt(this.gregorianTarget.value, 10)
    if (Number.isNaN(year)) {
      this.minguoTarget.value = ""
      this.render(null)
      return
    }
    this.minguoTarget.value = year - EPOCH
    this.render(year)
  }

  fromMinguo() {
    const year = parseInt(this.minguoTarget.value, 10)
    if (Number.isNaN(year)) {
      this.gregorianTarget.value = ""
      this.render(null)
      return
    }
    this.gregorianTarget.value = year + EPOCH
    this.render(year + EPOCH)
  }

  render(gregorian) {
    if (!this.hasNoteTarget) return
    if (gregorian === null) {
      this.noteTarget.textContent = ""
      return
    }
    const minguo = gregorian - EPOCH
    if (minguo < 1) {
      this.noteTarget.textContent = this.noteTarget.dataset.before || ""
      return
    }
    const template = this.noteTarget.dataset.template || ""
    this.noteTarget.textContent = template
      .replace("%{gregorian}", gregorian)
      .replace("%{minguo}", minguo)
  }
}
