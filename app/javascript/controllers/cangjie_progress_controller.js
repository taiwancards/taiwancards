import { Controller } from "@hotwired/stimulus";
import { load, pace, passed, typedChars } from "lib/cangjie_progress";

export default class extends Controller {
  static targets = [
    "panel",
    "lessons",
    "keys",
    "chars",
    "pace",
    "card",
    "cap",
    "chip",
  ];

  connect() {
    const state = load();
    this.decorate(state);
    this.fill(state);
  }

  decorate(state) {
    this.cardTargets.forEach((card) => {
      if (!passed(state.lessons[card.dataset.slug])) return;
      const mark = document.createElement("span");
      mark.className = "shrink-0 text-emerald-600";
      mark.textContent = "✓";
      card.append(mark);
    });
    this.capTargets.forEach((cap) => {
      if (!passed(state.lessons[cap.dataset.slug])) return;
      cap.classList.add("border-emerald-500/60");
    });
    const typed = typedChars(state);
    this.chipTargets.forEach((chip) => {
      if (!typed.has(chip.dataset.char)) return;
      chip.classList.add("border-emerald-500/60");
    });
  }

  fill(state) {
    if (!this.hasPanelTarget) return;

    const done = this.cardTargets.filter((card) =>
      passed(state.lessons[card.dataset.slug]),
    );
    const keyed = this.cardTargets.filter((card) => card.dataset.key);
    const keys = done.filter((card) => card.dataset.key);
    this.lessonsTarget.textContent = `${done.length} / ${this.cardTargets.length}`;
    this.keysTarget.textContent = `${keys.length} / ${keyed.length}`;
    this.charsTarget.textContent = typedChars(state).size;

    const rates = pace(state);
    if (rates) {
      const delta =
        rates.earlier > 0
          ? ` (${rates.current >= rates.earlier ? "↑" : "↓"}${Math.abs(Math.round(((rates.current - rates.earlier) / rates.earlier) * 100))}%)`
          : "";
      this.paceTarget.textContent = `${Math.round(rates.current)}${delta}`;
    } else {
      this.paceTarget.textContent = "—";
    }
    this.panelTarget.hidden = false;
  }
}
