import { Controller } from "@hotwired/stimulus";
import { keep, peek, problem, sweep } from "lib/door_stash";

export default class extends Controller {
  static targets = ["form", "text", "name", "message"];
  static values = {
    door: String,
    limit: Number,
    example: String,
    empty: String,
    noHanzi: String,
    tooLong: String,
    blocked: String,
  };

  connect() {
    sweep();
    const waiting = peek(this.doorValue, this.limitValue);
    if (waiting && !this.textTarget.value) {
      this.textTarget.value = waiting.text;
      this.nameTarget.value = waiting.name || "";
    }
  }

  example() {
    this.textTarget.value = this.exampleValue;
    this.say(null);
    this.textTarget.focus();
  }

  keep(event) {
    const text = this.textTarget.value;
    const issue = problem(text, this.limitValue);
    if (issue) {
      event.preventDefault();
      this.say(issue);
      this.textTarget.focus();
      return;
    }
    if (!keep(this.doorValue, text, this.nameTarget.value, this.limitValue)) {
      event.preventDefault();
      this.say("blocked");
    }
  }

  say(issue) {
    const messages = {
      empty: this.emptyValue,
      no_hanzi: this.noHanziValue,
      too_long: this.tooLongValue,
      blocked: this.blockedValue,
    };
    this.messageTarget.textContent = issue ? messages[issue] : "";
    this.messageTarget.hidden = !issue;
  }
}
