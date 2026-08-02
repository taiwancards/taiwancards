import { Controller } from "@hotwired/stimulus";

const KEYS = { ArrowUp: 1, ArrowRight: 2, ArrowDown: 3, ArrowLeft: 4 };

export default class extends Controller {
  static targets = ["option", "reveal", "gloss", "score"];
  static values = { items: Array, url: String };

  connect() {
    this.correct = 0;
    this.total = 0;
    this.queue = [...this.itemsValue];
    this.keyHandler = (event) => this.onKey(event);
    document.addEventListener("keydown", this.keyHandler);
    this.next();
  }

  disconnect() {
    document.removeEventListener("keydown", this.keyHandler);
    clearTimeout(this.timer);
    this.stop();
  }

  async next() {
    clearTimeout(this.timer);

    if (this.queue.length === 0) await this.refill();
    if (this.queue.length === 0) return;

    this.current = this.queue.shift();
    this.answered = false;
    this.revealTarget.textContent = "";
    this.glossTarget.textContent = "";
    this.optionTargets.forEach((node) => {
      node.className = this.optionClass();
    });
    this.play();
  }

  play() {
    this.stop();
    this.audio = new Audio(this.current.clip);
    this.audio.preload = "auto";

    const begin = () => {
      this.leadTimer = setTimeout(
        () => this.audio?.play().catch(() => {}),
        140,
      );
      if (this.current.stop_ms > 0) {
        this.watcher = () => {
          if (
            this.audio &&
            this.audio.currentTime >= this.current.stop_ms / 1000
          )
            this.stop();
        };
        this.audio.addEventListener("timeupdate", this.watcher);
      }
    };

    if (this.audio.readyState >= 3) return begin();
    this.audio.addEventListener("canplaythrough", begin, { once: true });
    this.audio.load();
  }

  replay() {
    if (this.current) this.play();
  }

  stop() {
    if (this.leadTimer) {
      clearTimeout(this.leadTimer);
      this.leadTimer = null;
    }
    if (!this.audio) return;

    if (this.watcher) {
      this.audio.removeEventListener("timeupdate", this.watcher);
      this.watcher = null;
    }
    this.audio.pause();
    this.audio = null;
  }

  onKey(event) {
    const tone = KEYS[event.key];
    if (!tone) return;
    event.preventDefault();
    this.grade(
      this.optionTargets.find((node) => Number(node.dataset.tone) === tone),
    );
  }

  choose(event) {
    this.grade(event.currentTarget);
  }

  grade(node) {
    if (this.answered || !this.current || !node) return;
    this.answered = true;

    const chosen = Number(node.dataset.tone);
    const good = chosen === this.current.tone;
    const right = this.optionTargets.find(
      (option) => Number(option.dataset.tone) === this.current.tone,
    );

    this.total += 1;
    if (good) this.correct += 1;
    else node.className = `${this.optionClass()} border-red-500 bg-red-500/10`;
    if (right)
      right.className = `${this.optionClass()} border-emerald-500 bg-emerald-500/10`;

    this.revealTarget.textContent = `${this.current.text} ${this.current.zhuyin}`;
    this.glossTarget.textContent = this.current.meaning || "";
    this.scoreTarget.textContent = this.scoreTarget.dataset.template
      .replace("%{correct}", this.correct)
      .replace("%{total}", this.total);

    this.timer = setTimeout(() => this.next(), good ? 900 : 1900);
  }

  more() {
    this.refill().then(() => this.next());
  }

  async refill() {
    if (!this.urlValue) return;

    try {
      const response = await fetch(this.urlValue, {
        headers: { Accept: "application/json" },
      });
      const data = await response.json();
      this.queue.push(...(data.items || []));
    } catch {}
  }

  optionClass() {
    return "flex min-h-16 w-full flex-col items-center justify-center gap-0 rounded-2xl border border-border bg-background px-2 py-3 text-center text-sm font-semibold transition-colors";
  }
}
