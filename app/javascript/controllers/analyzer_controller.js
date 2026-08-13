import { Controller } from "@hotwired/stimulus";
import { computePosition, offset, flip, shift } from "@floating-ui/dom";

export default class extends Controller {
  static targets = ["popover", "panel", "panelEmpty", "panelBody"];
  static values = { activateUrl: String, add: String, added: String };

  connect() {
    this.outside = (e) => {
      if (
        !this.popoverTarget.contains(e.target) &&
        !e.target.closest("[data-analyzer-target=word]")
      )
        this.close();
    };
    this.onScroll = () => this.close();
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
      this.panelBodyTarget.innerHTML = this.render(token);
      this.panelBodyTarget.classList.remove("hidden");
      return;
    }
    this.popoverTarget.innerHTML = this.render(token);
    this.popoverTarget.classList.remove("hidden");
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

  close() {
    this.popoverTarget.classList.add("hidden");
  }

  docked() {
    return (
      this.hasPanelTarget && window.matchMedia("(min-width: 1024px)").matches
    );
  }

  mark(anchor) {
    this.marked?.classList.remove("bg-primary/10");
    this.marked = anchor;
    anchor.classList.add("bg-primary/10");
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
    await fetch(this.activateUrlValue, {
      method: "POST",
      body,
      headers: token ? { "X-CSRF-Token": token } : {},
    });
    button.textContent = this.addedValue;
    button.disabled = true;
  }

  render(token) {
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
    const add = token.lexemeId
      ? `<button type="button" data-action="analyzer#add" data-lexeme-id="${token.lexemeId}" class="mt-2 w-full rounded-md border border-border px-2 py-1 text-xs font-medium hover:bg-muted">${this.addValue}</button>`
      : "";
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
