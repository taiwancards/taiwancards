import { Controller } from "@hotwired/stimulus";
import { typingElsewhere } from "lib/hotkeys";

const SIZES = { s: 0.85, m: 1, l: 1.25 };
const ORDER = Object.keys(SIZES);
const SIZE_KEY = "reading.size";

export default class extends Controller {
  static targets = ["line", "position", "progress", "sizeLabel", "saved"];

  connect() {
    this.index = 0;
    this.applySize(this.storedSize());
    this.paint();
    this.onKey = (event) => this.key(event);
    document.addEventListener("keydown", this.onKey);
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKey);
  }

  cycleSize() {
    const next = ORDER[(ORDER.indexOf(this.size) + 1) % ORDER.length];
    this.applySize(next);
    try {
      localStorage.setItem(SIZE_KEY, next);
    } catch {}
  }

  applySize(size) {
    this.size = size;
    this.element.style.setProperty("--reading-scale", SIZES[size]);
    this.sizeLabelTargets.forEach((label) => {
      label.textContent = size.toUpperCase();
    });
  }

  storedSize() {
    try {
      const stored = localStorage.getItem(SIZE_KEY);
      return ORDER.includes(stored) ? stored : "m";
    } catch {
      return "m";
    }
  }

  pick(event) {
    if (!this.focusing()) return;
    this.index = this.lineTargets.indexOf(event.currentTarget);
    this.paint();
  }

  next() {
    this.move(1);
  }

  previous() {
    this.move(-1);
  }

  move(step) {
    const index = this.index + step;
    if (index < 0 || index >= this.lineTargets.length) return;
    this.index = index;
    this.paint();
    this.lineTargets[index].scrollIntoView({
      behavior: "smooth",
      block: "center",
    });
  }

  key(event) {
    if (!this.focusing() || typingElsewhere(event)) return;
    if (event.key === "ArrowRight") this.next();
    if (event.key === "ArrowLeft") this.previous();
  }

  focusing() {
    return this.element.classList.contains("show-focus");
  }

  paint() {
    const total = this.lineTargets.length;
    this.lineTargets.forEach((line, index) => {
      line.classList.toggle("is-current", index === this.index);
    });
    this.positionTargets.forEach((position) => {
      position.textContent = `${this.index + 1} / ${total}`;
    });
    this.progressTargets.forEach((bar) => {
      bar.style.width = `${total ? ((this.index + 1) / total) * 100 : 0}%`;
    });
  }

  toggleLine(event) {
    event.stopPropagation();
    const button = event.currentTarget;
    const open = button.closest(".reading-line").classList.toggle("line-open");
    button.setAttribute("aria-expanded", String(open));
  }

  countSaved() {
    this.savedTargets.forEach((saved) => {
      saved.textContent = String(Number(saved.textContent) + 1);
    });
  }
}
