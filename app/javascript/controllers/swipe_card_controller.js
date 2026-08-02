import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "card",
    "back",
    "form",
    "rating",
    "elapsed",
    "goodLabel",
    "againLabel",
    "easyLabel",
    "hardLabel",
  ];

  connect() {
    this.shownAt = performance.now();
    this.dragging = false;
    this.dragged = false;
    this.submitted = false;
    this.keyHandler = (event) => this.onKey(event);
    document.addEventListener("keydown", this.keyHandler);
  }

  disconnect() {
    document.removeEventListener("keydown", this.keyHandler);
  }

  onKey(event) {
    if (event.key === "ArrowLeft") this.fling(-1, 0, "again");
    else if (event.key === "ArrowRight") this.fling(1, 0, "good");
    else if (event.key === "ArrowUp") {
      event.preventDefault();
      this.fling(0, -1, "easy");
    } else if (event.key === "ArrowDown") {
      event.preventDefault();
      this.fling(0, 1, "hard");
    } else if (event.key === " " || event.key === "Enter") {
      event.preventDefault();
      this.reveal();
    }
  }

  flip(event) {
    if (event && event.target.closest("button, a, [data-no-swipe]")) return;
    if (this.dragged) {
      this.dragged = false;
      return;
    }
    this.reveal();
  }

  reveal() {
    if (this.hasBackTarget) this.backTarget.classList.remove("hidden");
  }

  start(event) {
    if (event.button !== undefined && event.button !== 0) return;
    if (event.target.closest("button, a, [data-no-swipe]")) return;
    this.dragging = true;
    this.dragged = false;
    this.startX = event.clientX;
    this.startY = event.clientY;
    this.cardTarget.setPointerCapture(event.pointerId);
    this.cardTarget.style.transition = "none";
  }

  move(event) {
    if (!this.dragging) return;
    const dx = event.clientX - this.startX;
    const dy = event.clientY - this.startY;
    if (Math.abs(dx) > 8 || Math.abs(dy) > 8) this.dragged = true;
    this.position(dx, dy);
  }

  end(event) {
    if (!this.dragging) return;
    this.dragging = false;
    const dx = event.clientX - this.startX;
    const dy = event.clientY - this.startY;
    this.decide(
      dx,
      dy,
      this.cardTarget.offsetWidth * 0.28,
      this.cardTarget.offsetHeight * 0.22,
    );
  }

  cancel() {
    this.dragging = false;
    this.settle();
  }

  position(dx, dy) {
    this.cardTarget.style.transform = `translate(${dx}px, ${dy}px) rotate(${dx / 22}deg)`;
    const width = this.cardTarget.offsetWidth;
    const height = this.cardTarget.offsetHeight;
    const vertical = Math.abs(dy) > Math.abs(dx);
    const good = vertical ? 0 : Math.min(Math.max(dx / (width * 0.28), 0), 1);
    const again = vertical ? 0 : Math.min(Math.max(-dx / (width * 0.28), 0), 1);
    const easy = vertical ? Math.min(Math.max(-dy / (height * 0.22), 0), 1) : 0;
    const hard = vertical ? Math.min(Math.max(dy / (height * 0.22), 0), 1) : 0;
    this.setLabel("goodLabel", good);
    this.setLabel("againLabel", again);
    this.setLabel("easyLabel", easy);
    this.setLabel("hardLabel", hard);
  }

  setLabel(name, opacity) {
    const target = `${name}Target`;
    if (this[`has${name.charAt(0).toUpperCase()}${name.slice(1)}Target`])
      this[target].style.opacity = opacity;
  }

  decide(dx, dy, thresholdX, thresholdY) {
    const vertical = Math.abs(dy) > Math.abs(dx);
    if (vertical && dy < -thresholdY) this.fling(0, -1, "easy");
    else if (vertical && dy > thresholdY) this.fling(0, 1, "hard");
    else if (dx > thresholdX) this.fling(1, 0, "good");
    else if (dx < -thresholdX) this.fling(-1, 0, "again");
    else this.settle();
  }

  settle() {
    this.cardTarget.style.transition =
      "transform 200ms cubic-bezier(0.2, 0.8, 0.4, 1.2)";
    this.cardTarget.style.transform = "";
    this.fade();
  }

  fade() {
    this.setLabel("goodLabel", 0);
    this.setLabel("againLabel", 0);
    this.setLabel("easyLabel", 0);
    this.setLabel("hardLabel", 0);
  }

  fling(directionX, directionY, rating) {
    if (this.submitted) return;
    const width = this.cardTarget.offsetWidth;
    const height = this.cardTarget.offsetHeight;
    const x = directionX * width * 1.6;
    const y = directionY * height * 1.8 + (directionX !== 0 ? 20 : 0);
    this.cardTarget.style.transition =
      "transform 240ms ease-in, opacity 240ms ease-in";
    this.cardTarget.style.transform = `translate(${x}px, ${y}px) rotate(${x / 16}deg)`;
    this.cardTarget.style.opacity = "0.3";
    setTimeout(() => this.rate(rating), 170);
  }

  rateAgain() {
    this.fling(-1, 0, "again");
  }
  rateHard() {
    this.fling(0, 1, "hard");
  }
  rateGood() {
    this.fling(1, 0, "good");
  }
  rateEasy() {
    this.fling(0, -1, "easy");
  }

  rate(rating) {
    if (this.submitted) return;
    this.submitted = true;
    this.ratingTarget.value = rating;
    if (this.hasElapsedTarget)
      this.elapsedTarget.value = Math.round(performance.now() - this.shownAt);
    this.formTarget.requestSubmit();
  }
}
