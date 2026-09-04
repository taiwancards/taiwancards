import { Controller } from "@hotwired/stimulus";
import {
  ASSETS,
  FRAGMENTS,
  META,
  SHELLS,
  humanBytes,
  installed,
  json,
  readJson,
  saveInstalled,
  supported,
  writeJson,
} from "lib/offline_store";

const BATCH = 200;
const WARN_BYTES = 50 * 1048576;
const CORE = "core";
const MANIFEST_KEY = "/__meta/manifest";
const FRESH_MS = 300000;

export default class extends Controller {
  static targets = [
    "groups",
    "groupTemplate",
    "packTemplate",
    "storage",
    "persisted",
    "unsupported",
    "install",
    "installButton",
    "absent",
    "unavailable",
  ];

  static values = { base: String, browse: String, labels: Object };

  connect() {
    if (!supported()) {
      this.unsupportedTarget.classList.remove("hidden");
      return;
    }

    this.busy = null;
    this.prompt = null;
    if (document.documentElement.dataset.offline === "absent:1")
      this.absentTarget.classList.remove("hidden");
    this.catchInstall = (event) => this.offerInstall(event);
    window.addEventListener("beforeinstallprompt", this.catchInstall);
    this.load();
    this.showStorage();
  }

  disconnect() {
    window.removeEventListener("beforeinstallprompt", this.catchInstall);
  }

  get locale() {
    return this.labelsValue.locale || "en";
  }

  get unit() {
    return this.labelsValue.unit;
  }

  async load() {
    this.state = await installed();

    try {
      const response = await fetch(
        `${this.baseValue}/manifest.json?v=${Math.floor(Date.now() / FRESH_MS)}`,
        { cache: "no-cache" },
      );
      if (!response.ok) throw new Error(response.status);
      this.manifest = await response.json();
      await writeJson(META, MANIFEST_KEY, this.manifest);
    } catch (error) {
      this.manifest = (await readJson(META, MANIFEST_KEY)) || {
        packs: Object.values(this.state)
          .map((pack) => pack.manifest)
          .filter(Boolean),
      };
    }

    this.draw();
    this.reportEmpty();
  }

  reportEmpty() {
    if ((this.manifest.packs || []).length) return;

    this.unavailableTarget.textContent = this.labelsValue.unavailable;
    this.unavailableTarget.classList.remove("hidden");
  }

  draw() {
    this.groupsTarget.replaceChildren();
    const groups = {};

    for (const pack of this.manifest.packs || []) {
      (groups[pack.group] ||= []).push(pack);
    }

    for (const [group, packs] of Object.entries(groups)) {
      this.groupsTarget.append(this.groupNode(group, packs));
    }
  }

  groupNode(group, packs) {
    const node = this.groupTemplateTarget.content.cloneNode(true);
    node.querySelector('[data-field="title"]').textContent =
      this.labelsValue.groups[group] || group;
    node.querySelector('[data-field="summary"]').textContent =
      this.labelsValue.summaries[group] || "";
    const holder = node.querySelector('[data-field="packs"]');
    packs.forEach((pack) => holder.append(this.packNode(pack)));

    return node;
  }

  packNode(pack) {
    const node = this.packTemplateTarget.content.cloneNode(true);
    const row = node.querySelector("div");
    row.dataset.pack = pack.id;
    row.querySelector('[data-field="title"]').textContent =
      pack.titles[this.locale] || pack.id;
    row.querySelector('[data-field="size"]').textContent = humanBytes(
      this.sizeOf(pack),
      this.unit,
    );
    this.paint(row, pack);

    return node;
  }

  sizeOf(pack) {
    return (pack.bytes && pack.bytes[this.locale]) || 0;
  }

  status(pack) {
    const held = this.state[pack.id];
    if (!held) return "missing";

    return held.digest === pack.digest && held.locale === this.locale
      ? "ready"
      : "stale";
  }

  paint(row, pack) {
    const state = this.status(pack);
    const get = row.querySelector('[data-field="get"]');
    const remove = row.querySelector('[data-field="remove"]');

    const reachable = navigator.onLine !== false;

    row.querySelector('[data-field="state"]').textContent =
      this.labelsValue.state[state];
    get.textContent =
      state === "stale"
        ? this.labelsValue.action.update
        : this.labelsValue.action.download;
    get.classList.toggle("hidden", state === "ready" || !reachable);
    get.classList.toggle("inline-flex", state !== "ready" && reachable);
    remove.classList.toggle("hidden", state === "missing");
    remove.classList.toggle("inline-flex", state !== "missing");
  }

  packFor(event) {
    const row = event.target.closest("[data-pack]");

    return (this.manifest.packs || []).find(
      (pack) => pack.id === row.dataset.pack,
    );
  }

  async download(event) {
    if (this.busy) return;

    const pack = this.packFor(event);
    const core = (this.manifest.packs || []).find((row) => row.id === CORE);
    const needed =
      pack.id !== CORE && this.status(core) !== "ready" ? [core, pack] : [pack];
    const total = needed.reduce((sum, row) => sum + this.sizeOf(row), 0);

    if (
      total > WARN_BYTES &&
      !window.confirm(
        this.labelsValue.warn.replace("%{size}", humanBytes(total, this.unit)),
      )
    )
      return;

    this.busy = pack.id;

    try {
      for (const row of needed) await this.fetchPack(row);
      await this.keepAssets();
    } finally {
      this.busy = null;
      this.draw();
      this.showStorage();
    }
  }

  async fetchPack(pack) {
    const row = this.rowFor(pack.id);
    const chunks = (pack.chunks && pack.chunks[this.locale]) || [];
    const cache = await caches.open(FRAGMENTS);
    const paths = [];
    let done = 0;

    await this.dropPack(pack.id);

    for (const name of chunks) {
      const response = await fetch(`${this.baseValue}/${name}`);
      if (!response.ok) throw new Error(`${name} answered ${response.status}`);

      const batch = Object.entries(await response.json());

      for (let start = 0; start < batch.length; start += BATCH) {
        const slice = batch.slice(start, start + BATCH);
        await Promise.all(
          slice.map(([path, fragment]) => {
            paths.push(path);

            return cache.put(`/__frag${path}`, json(fragment));
          }),
        );
        done += slice.length;
        this.report(row, done, pack.pages);
      }
    }

    if (pack.index) await this.keepIndex(pack);
    if (pack.shells) await this.keepShells(pack);

    this.state[pack.id] = {
      digest: pack.digest,
      locale: this.locale,
      paths: paths,
      manifest: pack,
    };
    await saveInstalled(this.state);
  }

  report(row, done, total) {
    if (!row) return;

    row.querySelector('[data-field="state"]').textContent =
      this.labelsValue.working
        .replace("%{done}", done)
        .replace("%{total}", total);
  }

  rowFor(id) {
    return this.groupsTarget.querySelector(`[data-pack="${id}"]`);
  }

  async keepIndex(pack) {
    const response = await fetch(`${this.baseValue}/${pack.index}`);
    if (!response.ok) return;

    await writeJson(META, `/__index/${pack.id}`, await response.json());
  }

  async keepShells(pack) {
    const response = await fetch(`${this.baseValue}/${pack.shells}`);
    if (!response.ok) return;

    const shells = await response.json();
    const cache = await caches.open(SHELLS);

    for (const [locale, widths] of Object.entries(shells)) {
      for (const [width, html] of Object.entries(widths)) {
        await cache.put(
          `/__shell/${locale}/${width}`,
          new Response(html, {
            headers: { "content-type": "text/plain; charset=utf-8" },
          }),
        );
      }
    }
  }

  async keepAssets() {
    const cache = await caches.open(ASSETS);
    const wanted = performance
      .getEntriesByType("resource")
      .map((entry) => entry.name)
      .filter(
        (name) => /\/(assets|fonts|json)\//.test(name) || /\.woff2$/.test(name),
      )
      .concat(["/manifest"]);

    await Promise.all(
      [...new Set(wanted)].map((name) => cache.add(name).catch(() => {})),
    );
  }

  async remove(event) {
    const pack = this.packFor(event);
    await this.dropPack(pack.id);
    delete this.state[pack.id];
    await saveInstalled(this.state);
    this.draw();
    this.showStorage();
  }

  async dropPack(id) {
    const held = this.state[id];
    if (!held) return;

    const cache = await caches.open(FRAGMENTS);
    await Promise.all(
      (held.paths || []).map((path) => cache.delete(`/__frag${path}`)),
    );
  }

  async showStorage() {
    if (!navigator.storage || !navigator.storage.estimate) return;

    const { usage, quota } = await navigator.storage.estimate();
    this.storageTarget.textContent = this.labelsValue.storage
      .replace("%{used}", humanBytes(usage || 0, this.unit))
      .replace("%{quota}", humanBytes(quota || 0, this.unit));

    if (!navigator.storage.persist) return;

    const persisted =
      (await navigator.storage.persisted()) ||
      (await navigator.storage.persist());
    this.persistedTarget.textContent = persisted
      ? this.labelsValue.persisted
      : "";
  }

  offerInstall(event) {
    event.preventDefault();
    this.prompt = event;
    this.installTarget.classList.remove("hidden");
  }

  async install() {
    if (!this.prompt) return;

    this.prompt.prompt();
    await this.prompt.userChoice;
    this.prompt = null;
    this.installTarget.classList.add("hidden");
  }
}
