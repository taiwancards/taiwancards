import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "option",
    "feedback",
    "counter",
    "board",
    "summary",
    "correct",
    "total",
    "replay",
  ];
  static values = { items: Array, url: String };

  connect() {
    this.keyHandler = (event) => this.onKey(event);
    document.addEventListener("keydown", this.keyHandler);
    this.begin();
  }

  disconnect() {
    document.removeEventListener("keydown", this.keyHandler);
    clearTimeout(this.timer);
    this.stopAudio();
  }

  begin() {
    clearTimeout(this.timer);
    this.queue = [...this.itemsValue];
    this.planned = this.queue.length;
    this.done = 0;
    this.correct = 0;
    this.results = [];
    this.summaryTarget.classList.add("hidden");
    this.boardTarget.classList.remove("hidden");
    this.next();
  }

  next() {
    clearTimeout(this.timer);
    if (this.queue.length === 0) return this.finish();

    this.current = this.queue[0];
    this.answered = false;
    this.feedbackTarget.textContent = "";
    this.feedbackTarget.className = "mt-3 h-6 text-center text-sm font-medium";

    this.optionTargets.forEach((node, index) => {
      const symbol = this.current.options[index];
      node.dataset.symbol = symbol || "";
      node.dataset.correct = String(symbol === this.current.symbol);
      node.querySelector("[data-label]").textContent = symbol || "";
      node.className = this.optionClass();
    });

    this.counterTarget.textContent = `${this.done} / ${this.planned}`;
    this.askedAt = performance.now();
    this.play();
  }

  play() {
    this.stopAudio();
    this.audio = new Audio(this.current.clip);
    this.audio.preload = "auto";

    const begin = () => {
      this.leadTimer = setTimeout(
        () => this.audio?.play().catch(() => {}),
        140,
      );
    };

    if (this.audio.readyState >= 3) return begin();
    this.audio.addEventListener("canplaythrough", begin, { once: true });
    this.audio.load();
  }

  replay() {
    if (this.current) this.play();
  }

  stopAudio() {
    if (this.leadTimer) {
      clearTimeout(this.leadTimer);
      this.leadTimer = null;
    }
    if (!this.audio) return;

    this.audio.pause();
    this.audio = null;
  }

  optionClass() {
    return "flex min-h-20 w-full items-center justify-center rounded-2xl border border-border bg-background px-3 py-3 text-center text-4xl font-semibold transition-colors";
  }

  onKey(event) {
    if (event.key === " ") {
      event.preventDefault();
      return this.replay();
    }
    const map = {
      ArrowUp: "up",
      ArrowRight: "right",
      ArrowDown: "down",
      ArrowLeft: "left",
    };
    const direction = map[event.key];
    if (!direction) return;
    event.preventDefault();
    this.grade(
      this.optionTargets.find((node) => node.dataset.direction === direction),
    );
  }

  choose(event) {
    this.grade(event.currentTarget);
  }

  grade(node) {
    if (this.answered || !this.current || !node) return;
    this.answered = true;

    const elapsed = Math.round(performance.now() - this.askedAt);
    const good = node.dataset.correct === "true";
    const right = this.optionTargets.find(
      (option) => option.dataset.correct === "true",
    );

    if (!good)
      node.className = `${this.optionClass()} border-red-500 bg-red-500/10`;
    if (right)
      right.className = `${this.optionClass()} border-emerald-500 bg-emerald-500/10`;

    this.results.push({
      symbol: this.current.symbol,
      correct: good,
      elapsed_ms: elapsed,
    });

    if (good) {
      this.correct += 1;
      this.done += 1;
      this.queue.shift();
      this.feedbackTarget.classList.add("text-emerald-600");
      this.feedbackTarget.textContent = "✓";
    } else {
      const missed = this.queue.shift();
      this.queue.push(missed);
      this.feedbackTarget.classList.add("text-red-500");
      this.feedbackTarget.textContent = this.current.symbol;
    }

    this.timer = setTimeout(() => this.next(), good ? 700 : 1800);
  }

  finish() {
    this.current = null;
    this.stopAudio();
    this.boardTarget.classList.add("hidden");
    this.summaryTarget.classList.remove("hidden");
    this.correctTarget.textContent = this.correct;
    this.totalTarget.textContent = this.planned;
    this.submit();
  }

  async submit() {
    if (!this.urlValue || this.results.length === 0) return;

    try {
      await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token":
            document.querySelector("meta[name='csrf-token']")?.content || "",
        },
        body: JSON.stringify({ results: this.results }),
      });
    } catch {}
  }
}
