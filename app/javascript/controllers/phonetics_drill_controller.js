import { Controller } from "@hotwired/stimulus";

const DIRECTIONS = ["up", "right", "down", "left"];

export default class extends Controller {
  static targets = [
    "card",
    "prompt",
    "promptKind",
    "option",
    "feedback",
    "counter",
    "board",
    "summary",
    "correct",
    "total",
    "weakList",
    "exampleHanzi",
    "exampleZhuyin",
    "examplePinyin",
    "exampleGloss",
    "feedbackZhuyin",
    "feedbackPinyin",
  ];
  static values = {
    items: Object,
    weak: Object,
    url: String,
    size: Number,
    stage: String,
  };

  connect() {
    this.direction = "zhuyin";
    this.stage = this.stageValue || "consonants";
    this.keyHandler = (event) => this.onKey(event);
    document.addEventListener("keydown", this.keyHandler);
    this.begin();
  }

  disconnect() {
    document.removeEventListener("keydown", this.keyHandler);
    clearTimeout(this.advanceTimer);
  }

  setDirection(event) {
    this.direction = event.params.direction;
    this.begin();
  }

  setStage(event) {
    this.stage = event.params.stage;
    this.begin();
  }

  syncToggles() {
    this.element.querySelectorAll("[data-direction-option]").forEach((node) => {
      node.dataset.active = String(
        node.dataset.directionOption === this.direction,
      );
    });
    this.element.querySelectorAll("[data-stage-option]").forEach((node) => {
      node.dataset.active = String(node.dataset.stageOption === this.stage);
    });
  }

  begin() {
    clearTimeout(this.advanceTimer);
    const pool = this.itemsValue[this.stage] || [];
    const weak = this.weakValue || {};
    this.queue = pool
      .map((item) => ({ item, key: Math.random() - (weak[item.id] || 0) }))
      .sort((a, b) => a.key - b.key)
      .map((entry) => entry.item)
      .slice(0, Math.min(this.sizeValue, pool.length));

    this.planned = this.queue.length;
    this.done = 0;
    this.correct = 0;
    this.misses = {};
    this.summaryTarget.classList.add("hidden");
    this.boardTarget.classList.remove("hidden");
    this.syncToggles();
    this.next();
  }

  next() {
    clearTimeout(this.advanceTimer);
    if (this.queue.length === 0) return this.finish();

    this.current = this.queue[0];
    this.answered = false;
    this.setFeedback("", "");
    this.feedbackTarget.className = "mt-3 h-6 text-center text-sm font-medium";

    const asking = this.direction === "zhuyin";
    this.promptTarget.textContent = asking
      ? this.current.zhuyin
      : this.current.pinyin;
    this.promptTarget.lang = asking ? "zh-TW" : "en";
    this.promptKindTarget.textContent =
      this.promptKindTarget.dataset[this.direction];
    this.setExample(null);

    const wrong = this.shuffle([...this.current.distractors]).slice(
      0,
      this.optionTargets.length - 1,
    );
    const options = this.shuffle([
      { value: this.answerOf(this.current), correct: true },
      ...wrong.map((d) => ({
        value: asking ? d.pinyin : d.zhuyin,
        correct: false,
      })),
    ]);

    this.optionTargets.forEach((node, index) => {
      const option = options[index];
      node.dataset.correct = String(Boolean(option && option.correct));
      node.lang = asking ? "en" : "zh-TW";
      node.querySelector("[data-label]").textContent = option
        ? option.value
        : "";
      node.className = this.optionClass();
    });

    this.counterTarget.textContent = `${this.done} / ${this.planned}`;
    this.resetCard();
  }

  answerOf(item) {
    return this.direction === "zhuyin" ? item.pinyin : item.zhuyin;
  }

  optionClass() {
    return "flex min-h-16 w-full items-center justify-center rounded-2xl border border-border bg-background px-3 py-3 text-center text-lg font-semibold transition-colors";
  }

  shuffle(list) {
    return list
      .map((value) => ({ value, key: Math.random() }))
      .sort((a, b) => a.key - b.key)
      .map((entry) => entry.value);
  }

  onKey(event) {
    const map = {
      ArrowUp: "up",
      ArrowRight: "right",
      ArrowDown: "down",
      ArrowLeft: "left",
    };
    if (!map[event.key]) return;
    event.preventDefault();
    this.answer(map[event.key]);
  }

  choose(event) {
    this.answer(event.currentTarget.dataset.direction);
  }

  start(event) {
    if (event.target.closest("button, a")) return;
    this.startX = event.clientX;
    this.startY = event.clientY;
    this.dragging = true;
  }

  move(event) {
    if (!this.dragging) return;
    const dx = event.clientX - this.startX;
    const dy = event.clientY - this.startY;
    this.cardTarget.style.transition = "";
    this.cardTarget.style.transform = `translate(${dx * 0.4}px, ${dy * 0.4}px)`;
  }

  end(event) {
    if (!this.dragging) return;
    this.dragging = false;
    const dx = event.clientX - this.startX;
    const dy = event.clientY - this.startY;

    if (Math.abs(dx) < 24 && Math.abs(dy) < 24) return this.resetCard();
    const direction =
      Math.abs(dx) > Math.abs(dy)
        ? dx > 0
          ? "right"
          : "left"
        : dy > 0
          ? "down"
          : "up";
    this.answer(direction);
  }

  resetCard() {
    this.cardTarget.style.transition = "transform 150ms ease-out";
    this.cardTarget.style.transform = "";
  }

  answer(direction) {
    if (this.answered || !this.current) return;
    this.answered = true;
    this.resetCard();

    const chosen = this.optionTargets.find(
      (node) => node.dataset.direction === direction,
    );
    const right = this.optionTargets.find(
      (node) => node.dataset.correct === "true",
    );
    const good = chosen && chosen.dataset.correct === "true";

    if (chosen && !good)
      chosen.className = `${this.optionClass()} border-red-500 bg-red-500/10`;
    if (right)
      right.className = `${this.optionClass()} border-emerald-500 bg-emerald-500/10`;

    if (good) {
      this.correct += 1;
      this.done += 1;
      this.queue.shift();
      this.feedbackTarget.classList.add("text-emerald-600");
      this.setFeedback("✓", "");
    } else {
      this.misses[this.current.id] = (this.misses[this.current.id] || 0) + 1;
      const missed = this.queue.shift();
      this.queue.push(missed);
      this.feedbackTarget.classList.add("text-red-500");
      this.setFeedback(this.current.zhuyin, this.current.pinyin);
    }

    this.setExample();

    this.playAnswer();

    this.advanceTimer = setTimeout(() => this.next(), good ? 900 : 2300);
  }

  setFeedback(zhuyin, pinyin) {
    if (this.hasFeedbackZhuyinTarget)
      this.feedbackZhuyinTarget.textContent = zhuyin || "";
    if (this.hasFeedbackPinyinTarget)
      this.feedbackPinyinTarget.textContent = pinyin || "";
  }

  setExample(item = this.current) {
    const c = item;
    const has = Boolean(c && c.hanzi);
    if (this.hasExampleHanziTarget)
      this.exampleHanziTarget.textContent = has ? c.hanzi : "";
    if (this.hasExampleZhuyinTarget)
      this.exampleZhuyinTarget.textContent = has ? c.hanziZhuyin || "" : "";
    if (this.hasExamplePinyinTarget)
      this.examplePinyinTarget.textContent = has ? c.hanziPinyin || "" : "";
    if (this.hasExampleGlossTarget) {
      this.exampleGlossTarget.textContent =
        has && c.hanziGloss ? `\u2014 ${c.hanziGloss}` : "";
    }
  }

  playAnswer() {
    const symbols = String(this.current.zhuyin || "")
      .split("")
      .filter((symbol) => !"ˊˇˋ˙ˉ".includes(symbol));
    if (!symbols.length) return;

    symbols.forEach((symbol, index) => {
      setTimeout(() => {
        const audio = new Audio(`/zhuyin/${encodeURIComponent(symbol)}.opus`);
        audio.play().catch(() => {});
      }, index * 420);
    });
  }

  finish() {
    this.current = null;
    this.boardTarget.classList.add("hidden");
    this.summaryTarget.classList.remove("hidden");
    this.correctTarget.textContent = this.correct;
    this.totalTarget.textContent =
      this.correct + Object.values(this.misses).reduce((a, b) => a + b, 0);

    const pool = this.itemsValue[this.stage] || [];
    this.weakListTarget.textContent = Object.keys(this.misses)
      .map((id) => pool.find((item) => item.id === id))
      .filter(Boolean)
      .map((item) => `${item.zhuyin} ${item.pinyin}`)
      .join(" · ");

    this.persist();
  }

  persist() {
    if (Object.keys(this.misses).length === 0) return;
    const token = document.querySelector("meta[name='csrf-token']")?.content;
    this.weakValue = { ...this.weakValue, ...this.misses };
    if (!token) return;

    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": token,
      },
      body: JSON.stringify({ misses: this.misses }),
    }).catch(() => {});
  }
}

export { DIRECTIONS };
