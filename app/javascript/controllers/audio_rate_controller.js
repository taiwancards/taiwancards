import { Controller } from "@hotwired/stimulus";
import { RATES, audioRate, setAudioRate } from "lib/audio_rate";

const CHANGED = "audio-rate:changed";
const LABELS = { 1: "1×", 0.75: "¾×", 0.5: "½×" };

export default class extends Controller {
  static targets = ["label"];

  connect() {
    this.reflectHandler = () => this.reflect();
    document.addEventListener(CHANGED, this.reflectHandler);
    this.reflect();
  }

  disconnect() {
    document.removeEventListener(CHANGED, this.reflectHandler);
  }

  cycle() {
    const next = RATES[(RATES.indexOf(audioRate()) + 1) % RATES.length];
    setAudioRate(next);
    document.dispatchEvent(new CustomEvent(CHANGED));
  }

  reflect() {
    const rate = audioRate();
    this.element.setAttribute("aria-pressed", String(rate !== 1));
    this.element.dataset.audioRate = String(rate);
    if (this.hasLabelTarget) this.labelTarget.textContent = LABELS[rate];
  }
}
