import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["box"]

  apply(event) {
    const wanted = event.params.list.split(" ")
    this.boxTargets.forEach((box) => {
      box.checked = wanted.includes(box.dataset.facet)
    })
  }
}
