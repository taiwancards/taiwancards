import { Controller } from "@hotwired/stimulus";
import { take } from "lib/door_stash";

export default class extends Controller {
  static targets = ["form", "text", "name"];
  static values = { door: String, limit: Number, fallback: String };

  connect() {
    const pending = take(this.doorValue, this.limitValue);
    if (!pending) {
      window.location.replace(this.fallbackValue);
      return;
    }
    this.textTarget.value = pending.text;
    this.nameTarget.value = pending.name;
    this.formTarget.requestSubmit();
  }
}
