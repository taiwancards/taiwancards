import { Controller } from "@hotwired/stimulus";

const GAP = 14;
const PAD = 6;
const EDGE = 12;
const DESKTOP = "(min-width: 768px)";

export default class extends Controller {
  static targets = [
    "spotlight",
    "popover",
    "panel",
    "block",
    "hint",
    "forward",
    "next",
    "back",
    "title",
    "body",
    "counter",
    "backForm",
    "nextForm",
  ];
  static values = {
    steps: String,
    start: String,
    walkable: String,
    blocking: String,
    nextUrl: String,
    hintClick: String,
    hintScroll: String,
    counter: String,
  };

  connect() {
    this.place = this.place.bind(this);
    this.guard = this.guard.bind(this);
    this.intercept = this.intercept.bind(this);

    this.steps = this.readSteps();
    this.index = Math.max(
      0,
      this.steps.findIndex((step) => step.id === this.startValue),
    );

    window.addEventListener("resize", this.place);
    window.addEventListener("scroll", this.place, true);
    document.addEventListener("keydown", this.guard, true);
    document.addEventListener("click", this.intercept, true);

    this.render();
    document.fonts?.ready.then(this.place);
  }

  disconnect() {
    clearTimeout(this.settle);
    window.removeEventListener("resize", this.place);
    window.removeEventListener("scroll", this.place, true);
    document.removeEventListener("keydown", this.guard, true);
    document.removeEventListener("click", this.intercept, true);
    this.watcher?.disconnect();
  }

  readSteps() {
    let parsed = [];
    try {
      parsed = JSON.parse(this.stepsValue || "[]");
    } catch {
      parsed = [];
    }
    const viewport = window.matchMedia(DESKTOP).matches ? "desktop" : "mobile";
    const fitting = parsed.filter(
      (step) => !step.only || step.only === viewport,
    );
    return fitting.length ? fitting : parsed;
  }

  get walkable() {
    return this.walkableValue === "true";
  }

  get blocking() {
    return this.blockingValue === "true";
  }

  get current() {
    return this.steps[this.index] || null;
  }

  get awaitsClick() {
    return this.current?.action === "click";
  }

  get interactive() {
    return this.awaitsClick || this.current?.interactive === true;
  }

  get anchor() {
    const name = this.current?.target;
    if (!name) return null;

    return (
      [...document.querySelectorAll(`[data-tour="${name}"]`)].find((el) => {
        const box = el.getBoundingClientRect();
        return box.width > 0 && box.height > 0;
      }) || null
    );
  }

  render() {
    const step = this.current;
    if (!step) return;

    this.titleTarget.textContent = step.title || "";
    this.bodyTarget.textContent = step.body || "";
    this.counterTarget.textContent = this.walkable
      ? `${this.index + 1} / ${this.steps.length}`
      : this.counterValue;
    this.backTarget.classList.toggle(
      "hidden",
      !this.walkable && this.counterValue.startsWith("1 /"),
    );

    this.watcher?.disconnect();
    const el = this.anchor;
    if (el) {
      this.bring(el);
      this.watcher = new MutationObserver(this.place);
      this.watcher.observe(el, {
        attributes: true,
        childList: true,
        subtree: true,
      });
    }

    this.place();
    requestAnimationFrame(this.place);
    clearTimeout(this.settle);
    this.settle = setTimeout(this.place, 320);
  }

  bring(el) {
    const box = el.getBoundingClientRect();
    const room = window.innerHeight;
    const hidden =
      box.top < 80 || box.bottom > room - 80 || box.height > room * 0.7;
    if (!hidden) return;

    el.scrollIntoView({
      behavior: "smooth",
      block: "center",
      inline: "nearest",
    });
  }

  next() {
    if (this.index >= this.steps.length - 1)
      return this.nextFormTarget.requestSubmit();

    this.index += 1;
    this.sync();
    this.render();
  }

  back() {
    if (this.index === 0) return this.backFormTarget.requestSubmit();

    this.index -= 1;
    this.sync();
    this.render();
  }

  sync() {
    if (!this.walkable) return;

    const token = document.querySelector('meta[name="csrf-token"]')?.content;
    fetch(this.nextUrlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": token || "",
        "X-Requested-With": "XMLHttpRequest",
      },
      body: new URLSearchParams({ step: this.current?.id || "" }),
      credentials: "same-origin",
      keepalive: true,
    }).catch(() => {});
  }

  intercept(event) {
    this.place();
    if (!this.awaitsClick) return;

    const el = this.anchor;
    if (!el || !el.contains(event.target)) return;

    const step = this.current;
    if (step.landsOn) {
      const link = event.target.closest("a[href]");
      event.preventDefault();
      this.sync();
      setTimeout(() => {
        window.location = link?.getAttribute("href") || step.landsOn;
      }, 60);
      return;
    }

    setTimeout(() => {
      if (this.index < this.steps.length - 1) {
        this.index += 1;
        this.sync();
        this.render();
      }
    }, 120);
  }

  guard(event) {
    if (this.blocking && event.key === "Escape") {
      event.preventDefault();
      event.stopPropagation();
    }
  }

  reach(el) {
    const box = el.getBoundingClientRect();
    let { top, left, right, bottom } = box;

    el.querySelectorAll("*").forEach((child) => {
      const rect = child.getBoundingClientRect();
      if (rect.width === 0 || rect.height === 0) return;
      if (getComputedStyle(child).visibility === "hidden") return;

      top = Math.min(top, rect.top);
      left = Math.min(left, rect.left);
      right = Math.max(right, rect.right);
      bottom = Math.max(bottom, rect.bottom);
    });

    return {
      top,
      left,
      right,
      bottom,
      width: right - left,
      height: bottom - top,
    };
  }

  place() {
    const step = this.current;
    if (!step) return;

    const el = this.anchor;
    const hole = el ? this.reach(el) : null;

    this.guided = Boolean(hole) && this.interactive;

    if (this.hasHintTarget) {
      const hint = this.awaitsClick
        ? this.hintClickValue
        : step.action === "scroll"
          ? this.hintScrollValue
          : "";
      this.hintTarget.textContent = hint;
      this.hintTarget.classList.toggle("hidden", !hint || !hole);
    }
    this.forwardTarget.classList.toggle(
      "hidden",
      Boolean(hole) && this.awaitsClick,
    );
    this.spotlightTarget.classList.toggle("intro-beacon", this.guided);

    this.frame(hole);
    if (!hole) return this.center();

    const spot = this.spotlightTarget.style;
    spot.opacity = "1";
    spot.top = `${hole.top - PAD}px`;
    spot.left = `${hole.left - PAD}px`;
    spot.width = `${hole.width + PAD * 2}px`;
    spot.height = `${hole.height + PAD * 2}px`;

    this.perch(hole);
  }

  perch(hole) {
    const pop = this.popoverTarget;
    const width = pop.offsetWidth;
    const height = pop.offsetHeight;
    const room = window.innerHeight;

    const below = hole.bottom + GAP;
    const above = hole.top - height - GAP;
    let top;

    if (below + height <= room - EDGE) {
      top = below;
    } else if (above >= EDGE) {
      top = above;
    } else {
      const overBottom = room - height - EDGE;
      const clear = hole.top - EDGE >= height ? EDGE : overBottom;
      top = Math.max(EDGE, Math.min(clear, overBottom));
    }

    let left = hole.left + hole.width / 2 - width / 2;
    left = Math.min(Math.max(EDGE, left), window.innerWidth - width - EDGE);

    pop.style.top = `${Math.max(EDGE, top)}px`;
    pop.style.left = `${left}px`;
    pop.style.transform = "";
  }

  frame(hole) {
    const full = {
      top: 0,
      left: 0,
      right: window.innerWidth,
      bottom: window.innerHeight,
    };
    const box = hole
      ? {
          top: Math.max(0, hole.top - PAD),
          left: Math.max(0, hole.left - PAD),
          right: Math.min(full.right, hole.right + PAD),
          bottom: Math.min(full.bottom, hole.bottom + PAD),
        }
      : {
          top: full.bottom,
          left: full.right,
          right: full.right,
          bottom: full.bottom,
        };

    const sides = [
      { top: 0, left: 0, width: full.right, height: box.top },
      {
        top: box.bottom,
        left: 0,
        width: full.right,
        height: full.bottom - box.bottom,
      },
      { top: box.top, left: 0, width: box.left, height: box.bottom - box.top },
      {
        top: box.top,
        left: box.right,
        width: full.right - box.right,
        height: box.bottom - box.top,
      },
    ];

    this.panelTargets.forEach((panel, index) => {
      const side = sides[index];
      panel.style.top = `${Math.max(0, side.top)}px`;
      panel.style.left = `${Math.max(0, side.left)}px`;
      panel.style.width = `${Math.max(0, side.width)}px`;
      panel.style.height = `${Math.max(0, side.height)}px`;
    });

    const cover = this.blockTarget.style;
    const sealed = !this.guided;
    cover.display = sealed ? "block" : "none";
    if (!sealed) return;

    cover.top = `${box.top}px`;
    cover.left = `${box.left}px`;
    cover.width = `${Math.max(0, box.right - box.left)}px`;
    cover.height = `${Math.max(0, box.bottom - box.top)}px`;
  }

  center() {
    const spot = this.spotlightTarget.style;
    spot.opacity = "0";
    spot.width = "0px";
    spot.height = "0px";

    const pop = this.popoverTarget;
    pop.style.top = "50%";
    pop.style.left = "50%";
    pop.style.transform = "translate(-50%, -50%)";
  }
}
