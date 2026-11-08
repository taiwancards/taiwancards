import { Controller } from "@hotwired/stimulus";
import { computePosition, offset, flip, shift } from "@floating-ui/dom";

const MARK = ["bg-amber-300/60", "dark:bg-amber-400/30"];
const SHEET_GAP = 12;

export default class extends Controller {
  static targets = ["popover", "panel", "panelEmpty", "panelBody", "word"];
  static values = {
    activateUrl: String,
    add: String,
    added: String,
    loginUrl: String,
    signIn: String,
  };

  connect() {
    this.outside = (e) => {
      if (
        !this.popoverTarget.contains(e.target) &&
        !e.target.closest("[data-analyzer-target=word]")
      )
        this.close();
    };
    this.onScroll = () => {
      if (!this.sheet) this.close();
    };
    document.addEventListener("click", this.outside);
    window.addEventListener("scroll", this.onScroll, true);
    this.escHandler = (e) => e.key === "Escape" && this.close();
    document.addEventListener("keydown", this.escHandler);
  }

  disconnect() {
    document.removeEventListener("click", this.outside);
    window.removeEventListener("scroll", this.onScroll, true);
    document.removeEventListener("keydown", this.escHandler);
  }

  open(event) {
    const anchor = event.currentTarget;
    const token = JSON.parse(anchor.dataset.token);
    if (this.docked()) {
      if (event.type === "mouseenter") return;
      this.mark(anchor);
      this.panelEmptyTarget.hidden = true;
      this.panelBodyTarget.innerHTML = this.render(token, anchor);
      this.panelBodyTarget.classList.remove("hidden");
      return;
    }
    this.mark(anchor);
    this.popoverTarget.innerHTML = this.render(token, anchor);
    this.popoverTarget.classList.remove("hidden");

    if (this.narrow()) {
      this.sheet = true;
      Object.assign(this.popoverTarget.style, {
        left: "0.75rem",
        right: "0.75rem",
        bottom: "5.5rem",
        top: "auto",
        width: "auto",
        maxWidth: "none",
      });
      this.keepAboveSheet(anchor);
      return;
    }

    this.sheet = false;
    Object.assign(this.popoverTarget.style, {
      right: "",
      bottom: "",
      width: "",
      maxWidth: "",
    });
    computePosition(anchor, this.popoverTarget, {
      placement: "top",
      strategy: "fixed",
      middleware: [offset(8), flip(), shift({ padding: 8 })],
    }).then(({ x, y }) => {
      Object.assign(this.popoverTarget.style, {
        left: `${x}px`,
        top: `${y}px`,
      });
    });
  }

  narrow() {
    return window.matchMedia("(max-width: 1023px)").matches;
  }

  keepAboveSheet(anchor) {
    const overlap =
      anchor.getBoundingClientRect().bottom +
      SHEET_GAP -
      this.popoverTarget.getBoundingClientRect().top;
    if (overlap > 0) window.scrollBy({ top: overlap, behavior: "smooth" });
  }

  close() {
    this.sheet = false;
    this.popoverTarget.classList.add("hidden");
    if (!this.docked()) this.unmark();
  }

  docked() {
    return (
      this.hasPanelTarget && window.matchMedia("(min-width: 1024px)").matches
    );
  }

  mark(anchor) {
    this.unmark();
    this.marked = anchor;
    anchor.classList.add(...MARK);
  }

  unmark() {
    this.marked?.classList.remove(...MARK);
    this.marked = null;
  }

  play(event) {
    const url = event.currentTarget.dataset.url;
    if (url) new Audio(url).play();
  }

  async add(event) {
    const button = event.currentTarget;
    const body = new FormData();
    body.append("lexeme_id", button.dataset.lexemeId);
    const token = document.querySelector('meta[name="csrf-token"]')?.content;
    button.disabled = true;
    const response = await fetch(this.activateUrlValue, {
      method: "POST",
      body,
      headers: token ? { "X-CSRF-Token": token } : {},
    }).catch(() => null);
    if (!response?.ok) {
      button.disabled = false;
      return;
    }
    button.textContent = this.addedValue;
    this.markSaved(button.dataset.lexemeId);
  }

  markSaved(lexemeId) {
    this.wordTargets
      .filter((word) => word.dataset.lexemeId === lexemeId)
      .forEach((word) => {
        word.dataset.saved = "true";
        word.classList.add("word-saved");
      });
    this.dispatch("saved");
  }

  saveControl(token, anchor) {
    if (!token.lexemeId) return "";
    if (anchor.dataset.saved === "true") {
      return `<div class="mt-2 text-center text-xs text-muted-foreground">${this.addedValue}</div>`;
    }
    if (this.activateUrlValue) {
      return `<button type="button" data-action="analyzer#add" data-lexeme-id="${token.lexemeId}" class="mt-2 min-h-11 w-full rounded-md border border-border px-2 py-1 text-xs font-medium hover:bg-muted md:min-h-8">${this.addValue}</button>`;
    }
    if (this.loginUrlValue) {
      return `<a href="${this.loginUrlValue}" class="mt-2 flex min-h-11 items-center justify-center rounded-md border border-border px-2 py-1 text-xs font-medium hover:bg-muted md:min-h-8">${this.signInValue}</a>`;
    }
    return "";
  }

  render(token, anchor) {
    const zhuyin = token.zhuyin
      ? `<span class="zhuyin" lang="zh-TW">${token.zhuyin}</span>`
      : "";
    const pinyin = token.pinyin
      ? `<span class="pinyin">${token.zhuyin ? " · " : ""}${token.pinyin}</span>`
      : "";
    const reading = `${zhuyin}${pinyin}`;
    const chars = (token.chars || [])
      .map(
        (
          c,
        ) => `<div class="grid grid-cols-[1.5rem_auto_1fr] items-baseline gap-x-2 gap-y-0.5 text-sm">
          <span lang="zh-TW" class="text-base">${c.text}</span>
          <span class="zhuyin whitespace-nowrap text-muted-foreground" lang="zh-TW">${c.zhuyin || ""}</span>
          <span class="text-muted-foreground">${c.meaning || ""}</span>
        </div>`,
      )
      .join("");
    const audio = token.audio
      ? `<button type="button" data-action="analyzer#play" data-url="${token.audio}" class="shrink-0 rounded-full p-1 text-muted-foreground hover:text-foreground">♪</button>`
      : "";
    const add = this.saveControl(token, anchor);
    const link = token.href
      ? `<a href="${token.href}" class="text-lg font-semibold text-primary hover:underline" lang="zh-TW">${token.text}</a>`
      : `<span class="text-lg font-semibold" lang="zh-TW">${token.text}</span>`;
    return `
      <div class="flex items-center justify-between gap-2">${link}${audio}</div>
      ${reading ? `<div class="mt-0.5 whitespace-nowrap text-sm font-medium">${reading}</div>` : ""}
      ${token.pos ? `<div class="text-[10px] uppercase tracking-wide text-muted-foreground">${token.pos}</div>` : ""}
      ${token.meaning ? `<div class="mt-1 text-sm">${token.meaning}</div>` : ""}
      ${chars ? `<div class="mt-2 space-y-1 border-t border-border pt-2">${chars}</div>` : ""}
      ${add}
    `;
  }
}
