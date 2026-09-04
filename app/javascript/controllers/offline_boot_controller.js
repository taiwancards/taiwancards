import { Controller } from "@hotwired/stimulus";
import { META, supported, writeJson } from "lib/offline_store";

export default class extends Controller {
  connect() {
    this.watch = () => this.mark();
    window.addEventListener("online", this.watch);
    window.addEventListener("offline", this.watch);
    this.mark();
    this.register();
    if (!this.cached) this.keepAssets();
  }

  disconnect() {
    window.removeEventListener("online", this.watch);
    window.removeEventListener("offline", this.watch);
  }

  get cached() {
    return document.documentElement.dataset.offline !== undefined;
  }

  mark() {
    document.documentElement.classList.toggle(
      "offline",
      this.cached || navigator.onLine === false,
    );
  }

  register() {
    if (!("serviceWorker" in navigator)) return;

    navigator.serviceWorker.register("/sw.js").catch(() => {});
  }

  async keepAssets() {
    if (!supported()) return;

    const css = this.tags('link[rel="stylesheet"]');
    const js = [
      ...this.nodes('script[type="importmap"]'),
      ...this.nodes('link[rel="modulepreload"]'),
      ...this.nodes('script[type="module"]'),
    ]
      .map((node) => node.outerHTML)
      .join("");

    if (!css || !js) return;

    await writeJson(META, "/__meta/assets", { css, js });
  }

  nodes(selector) {
    return Array.from(document.head.querySelectorAll(selector));
  }

  tags(selector) {
    return this.nodes(selector)
      .map((node) => node.outerHTML)
      .join("");
  }
}
