import { Controller } from "@hotwired/stimulus";

const STORE = "layers.";

export default class extends Controller {
  static targets = ["button"];

  connect() {
    this.layers().forEach((layer) => this.apply(layer, this.stored(layer)));
  }

  toggle(event) {
    const layer = event.currentTarget.dataset.layer;
    const shown = !this.element.classList.contains(`show-${layer}`);
    this.store(layer, shown);
    this.apply(layer, shown);
  }

  apply(layer, shown) {
    this.element.classList.toggle(`show-${layer}`, shown);
    this.buttonTargets
      .filter((button) => button.dataset.layer === layer)
      .forEach((button) => {
        button.setAttribute("aria-pressed", String(shown));
        button.classList.toggle("border-primary", shown);
        button.classList.toggle("text-primary", shown);
        button.classList.toggle("text-muted-foreground", !shown);
      });
  }

  layers() {
    return [
      ...new Set(this.buttonTargets.map((button) => button.dataset.layer)),
    ];
  }

  stored(layer) {
    try {
      return localStorage.getItem(STORE + layer) === "1";
    } catch {
      return false;
    }
  }

  store(layer, shown) {
    try {
      localStorage.setItem(STORE + layer, shown ? "1" : "0");
    } catch {}
  }
}
