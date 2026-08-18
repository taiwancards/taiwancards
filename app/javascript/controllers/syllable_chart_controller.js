import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { templates: Object, voice: String };
  static targets = ["voiceButton"];

  connect() {
    this.mark();
  }

  disconnect() {
    this.halt();
  }

  choose(event) {
    this.voiceValue = event.currentTarget.dataset.voice;
    this.mark();
  }

  mark() {
    for (const button of this.voiceButtonTargets) {
      const chosen = button.dataset.voice === this.voiceValue;
      button.setAttribute("aria-pressed", chosen ? "true" : "false");
    }
  }

  play(event) {
    const key = event.currentTarget.dataset.key;
    const template = this.templatesValue[this.voiceValue];
    if (!key || !template) return;

    this.halt();
    this.sound = new Audio(template.replace("%s", key));
    this.sound.play().catch(() => {});
  }

  halt() {
    if (!this.sound) return;
    this.sound.pause();
    this.sound = null;
  }
}
