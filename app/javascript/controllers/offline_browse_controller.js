import { Controller } from "@hotwired/stimulus";
import { indexFor, installed, supported } from "lib/offline_store";

const LIMIT = 200;
const TONES = /[̄́̌̀]/g;

export default class extends Controller {
  static targets = [
    "query",
    "kinds",
    "results",
    "count",
    "empty",
    "rowTemplate",
    "chipTemplate",
  ];

  static values = { labels: Object };

  connect() {
    this.rows = [];
    this.kind = "";
    this.pack = "";
    this.applyPreset();
    this.load();
  }

  applyPreset() {
    const preset = document.documentElement.dataset.offline || "";
    const [key, value] = preset.split(":");
    if (key === "kind") this.kind = value || "";
    if (key === "pack") this.pack = value || "";

    const asked = new URLSearchParams(window.location.search).get("q");
    if (asked) this.queryTarget.value = asked;
  }

  async load() {
    if (!supported()) return this.finish();

    const state = await installed();
    const ids = Object.keys(state);

    for (const id of ids) {
      const index = await indexFor(id);
      if (!index) continue;

      index.rows.forEach((row) =>
        this.rows.push({ row: row, pack: id, hay: haystack(row) }),
      );
    }

    this.settleKind();
    this.drawKinds();
    this.finish();
  }

  finish() {
    this.emptyTarget.textContent = this.rows.length
      ? ""
      : this.labelsValue.empty;
    this.render();
  }

  settleKind() {
    if (!this.kind) return;
    if (this.rows.some((entry) => entry.row[6] === this.kind)) return;

    this.kind = "";
  }

  drawKinds() {
    const present = [...new Set(this.rows.map((entry) => entry.row[6]))];
    this.kindsTarget.replaceChildren();

    [
      ["", this.labelsValue.all],
      ...present.map((kind) => [kind, this.labelsValue.kinds[kind] || kind]),
    ].forEach(([kind, label]) => {
      const node = this.chipTemplateTarget.content.cloneNode(true);
      const chip = node.querySelector("button");
      chip.dataset.kind = kind;
      chip.textContent = label;
      chip.classList.toggle("bg-primary", kind === this.kind);
      chip.classList.toggle("text-primary-foreground", kind === this.kind);
      this.kindsTarget.append(node);
    });
  }

  filter(event) {
    this.kind = event.currentTarget.dataset.kind || "";
    this.drawKinds();
    this.render();
  }

  search() {
    this.render();
  }

  matches() {
    const needle = normalise(this.queryTarget.value.trim());

    return this.rows.filter((entry) => {
      if (this.kind && entry.row[6] !== this.kind) return false;
      if (this.pack && entry.pack !== this.pack) return false;

      return needle === "" || entry.hay.includes(needle);
    });
  }

  render() {
    const found = this.matches();
    this.countTarget.textContent = this.labelsValue.count.replace(
      "%{count}",
      found.length,
    );
    this.emptyTarget.textContent =
      this.rows.length && !found.length
        ? this.labelsValue.none
        : this.emptyTarget.textContent;
    this.resultsTarget.replaceChildren();

    found
      .slice(0, LIMIT)
      .forEach((entry) => this.resultsTarget.append(this.rowNode(entry.row)));
  }

  rowNode(row) {
    const node = this.rowTemplateTarget.content.cloneNode(true);
    const link = node.querySelector("a");
    link.href = `/${this.labelsValue.locale}${row[5]}`;
    link.querySelector('[data-field="text"]').textContent = row[0];
    link.querySelector('[data-field="reading"]').textContent =
      row[1] || row[2] || "";
    link.querySelector('[data-field="gloss"]').textContent =
      this.labelsValue.locale === "ru" ? row[4] : row[3];

    return node;
  }
}

function normalise(text) {
  return text.toLowerCase().normalize("NFD").replace(TONES, "");
}

function haystack(row) {
  return normalise([row[0], row[1], row[2], row[3], row[4]].join(" "));
}
