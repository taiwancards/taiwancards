import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "card",
    "text",
    "zhuyin",
    "pinyin",
    "meaning",
    "lines",
    "abbr",
    "abbrText",
    "abbrReading",
    "link",
    "empty",
  ];
  static values = { cards: Object };

  connect() {
    this.keyHandler = (event) => {
      if (event.key === "Escape") this.close();
    };
    document.addEventListener("keydown", this.keyHandler);
  }

  disconnect() {
    document.removeEventListener("keydown", this.keyHandler);
  }

  open(event) {
    const name = event.currentTarget.dataset.station;
    const card = this.cardsValue[name];
    if (!card) return;

    this.element.querySelectorAll("[data-station]").forEach((node) => {
      node.dataset.active = String(node.dataset.station === name);
    });

    this.textTarget.textContent = card.text;
    this.zhuyinTarget.textContent = card.zhuyin || "";
    this.pinyinTarget.textContent = card.pinyin || "";
    this.meaningTarget.textContent = card.meaning || "";
    this.linesTarget.textContent = card.lines.join(" · ");
    this.abbrTextTarget.textContent = card.abbr || "";
    this.abbrReadingTarget.textContent = card.abbrReading || "";
    this.abbrTarget.classList.toggle("hidden", !card.abbr);
    this.linkTarget.href = card.href;

    this.emptyTarget.classList.add("hidden");
    this.cardTarget.classList.remove("hidden");
  }

  close() {
    this.element.querySelectorAll("[data-station]").forEach((node) => {
      node.dataset.active = "false";
    });
    this.cardTarget.classList.add("hidden");
    this.emptyTarget.classList.remove("hidden");
  }
}
