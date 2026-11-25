import { Controller } from "@hotwired/stimulus";
import { applyAudioRate } from "lib/audio_rate";
import { csrfToken } from "lib/csrf";
import {
  attemptKey,
  best,
  clock,
  groupsOf,
  history,
  keepPending,
  listeningSchedule,
  mark,
  nextClipAfter,
  withEdition,
  partTitle,
  readStore,
  remember,
  resumeStep,
  scaled,
  secondsLeft,
  takePending,
  writeStore,
} from "lib/exam_paper";

const RATE_CHANGED = "audio-rate:changed";
const CLIP_FAILURE_GRACE_MS = 1500;
const ZOOMED = ["w-[200%]", "max-w-none"];
const MANDARIN_RUN =
  /([\p{Script=Han}\u3000-\u303f\uff01-\uff0f\uff1a-\uff20\u2026\u2014]+(?:[\s(（A-D)）]*[\p{Script=Han}\u3000-\u303f\uff01-\uff0f\uff1a-\uff20\u2026\u2014]+)*)/u;

function h(tag, props = {}, ...children) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(props)) {
    if (value === null || value === undefined || value === false) continue;
    if (key === "class") node.className = value;
    else if (key === "text") node.textContent = value;
    else if (key.startsWith("on")) node.addEventListener(key.slice(2), value);
    else node.setAttribute(key, value === true ? "" : value);
  }
  for (const child of children.flat(Infinity))
    if (child !== null && child !== undefined && child !== false)
      node.append(child);
  return node;
}

const encodePath = (path) =>
  String(path).split("/").map(encodeURIComponent).join("/");

export default class extends Controller {
  static targets = [
    "loading",
    "failed",
    "setup",
    "resume",
    "resumeNote",
    "adaptive",
    "history",
    "stage",
    "result",
    "zoom",
    "zoomFrame",
    "handover",
  ];

  static values = {
    bundle: String,
    media: String,
    slug: String,
    record: String,
    save: String,
    index: String,
    locale: String,
    thresholds: Array,
    strings: Object,
  };

  connect() {
    this.player = new Audio();
    this.preloader = new Audio();
    this.preloader.preload = "auto";
    this.rateHandler = () => this.practiceRate();
    document.addEventListener(RATE_CHANGED, this.rateHandler);
    for (const node of [this.stageTarget, this.resultTarget]) {
      node.replaceChildren();
      this.toggle(node, false);
    }
    this.toggle(this.setupTarget, false);
    this.renderHistory();
    this.handOver();
    this.load();
  }

  disconnect() {
    document.removeEventListener(RATE_CHANGED, this.rateHandler);
    this.halt();
    clearInterval(this.ticker);
    this.releaseWakeLock();
  }

  t(key, vars = {}) {
    const text = this.stringsValue[key] ?? key;
    return text.replace(/%\{(\w+)\}/g, (_, name) => vars[name] ?? "");
  }

  levelName(name) {
    const match = /^(Level|Novice) (\d)$/.exec(name || "");
    if (!match) return name;
    return this.t(match[1] === "Level" ? "level_n" : "novice_n", {
      n: match[2],
    });
  }

  async load() {
    this.toggle(this.loadingTarget, true);
    this.toggle(this.failedTarget, false);
    try {
      const address = new URL(this.bundleValue, window.location.href);
      const response = await fetch(address, {
        headers: { Accept: "application/json" },
      });
      if (!response.ok) throw new Error(String(response.status));
      this.bundle = withEdition(await response.json(), this.localeValue);
      this.publishedLevels =
        Boolean(this.bundle.scale) &&
        !this.bundle.scale.thresholds?.length &&
        this.thresholdsValue.length > 0;
      if (this.publishedLevels)
        this.bundle.scale.thresholds = this.thresholdsValue;
      this.address = address;
      this.digest = address.searchParams.get("v") || "";
      this.groups = groupsOf(this.bundle);
      this.listening = this.bundle.skill === "listening";
      this.toggle(this.loadingTarget, false);
      this.toggle(this.setupTarget, true);
      this.offerResume();
    } catch {
      this.toggle(this.loadingTarget, false);
      this.toggle(this.failedTarget, true);
    }
  }

  retry() {
    this.load();
  }

  toggle(node, visible) {
    node.hidden = !visible;
  }

  saved() {
    const state = readStore(attemptKey(this.slugValue));
    if (!state || state.digest !== this.digest || state.finished) return null;
    return state;
  }

  offerResume() {
    const state = this.saved();
    this.toggle(this.resumeTarget, Boolean(state));
    if (!state) return;
    this.resumeNoteTarget.textContent = this.t("resume_note", {
      count: Object.keys(state.answers).length,
      total: this.bundle.count,
      mode: this.modeLabel(state),
    });
  }

  modeLabel(state) {
    if (state.mode === "practice") return this.t("practice");
    return state.adaptive ? this.t("adaptive") : this.t("exam");
  }

  start(event) {
    event.preventDefault();
    const form = event.target.closest("form") || this.setupTarget;
    const mode = form.querySelector("input[name=mode]:checked")?.value;
    const adaptive =
      this.listening &&
      mode === "exam" &&
      this.hasAdaptiveTarget &&
      this.adaptiveTarget.checked;
    const now = Date.now();
    this.schedule = null;
    this.state = {
      digest: this.digest,
      mode: mode === "exam" ? "exam" : "practice",
      adaptive: Boolean(adaptive),
      startedAt: now,
      deadline:
        mode === "exam" && !this.listening && Number(this.bundle.minutes) > 0
          ? now + Number(this.bundle.minutes) * 60000
          : null,
      answers: {},
      revealed: [],
      locked: [],
      view: 0,
      step: 0,
      finished: false,
    };
    this.begin(0);
  }

  resume(event) {
    event.preventDefault();
    const state = this.saved();
    if (!state) return this.offerResume();
    this.schedule = null;
    this.state = state;
    this.begin(this.examListening() ? resumeStep(this.steps(), state.step) : 0);
  }

  discard(event) {
    event.preventDefault();
    writeStore(attemptKey(this.slugValue), null);
    this.offerResume();
  }

  examListening() {
    return this.listening && this.state?.mode === "exam";
  }

  steps() {
    this.schedule ||= listeningSchedule(this.bundle, {
      adaptive: this.state.adaptive,
    });
    return this.schedule;
  }

  begin(stepIndex) {
    this.unlockAudio();
    this.toggle(this.setupTarget, false);
    this.toggle(this.resultTarget, false);
    this.toggle(this.stageTarget, true);
    this.save();
    this.renderStage();
    this.stageTarget.scrollIntoView({ block: "start" });

    if (this.examListening()) {
      this.holdWakeLock();
      this.runFrom(stepIndex);
    } else if (this.state.deadline) {
      this.ticker = setInterval(() => this.tick(), 1000);
      this.tick();
    }
  }

  unlockAudio() {
    this.player.muted = true;
    this.player.src = SILENCE;
    this.player.play().catch(() => {});
    this.player.pause();
    this.player.muted = false;
  }

  async holdWakeLock() {
    try {
      this.wakeLock = await navigator.wakeLock?.request("screen");
    } catch {}
  }

  releaseWakeLock() {
    this.wakeLock?.release?.().catch(() => {});
    this.wakeLock = null;
  }

  save() {
    if (this.state && !this.state.finished)
      writeStore(attemptKey(this.slugValue), this.state);
  }

  tick() {
    const left = secondsLeft(this.state.deadline);
    this.renderStatus();
    if (left <= 0) this.finish();
  }

  clipUrl(path) {
    return `${this.mediaValue}${encodePath(path)}`;
  }

  imageUrl(path) {
    const url = new URL(path, this.address);
    if (this.digest) url.searchParams.set("v", this.digest);
    return url.toString();
  }

  preload(name) {
    if (!name) return;
    const url = this.clipUrl(name);
    if (this.preloaded === url) return;
    this.preloaded = url;
    this.preloader.src = url;
    this.preloader.load();
  }

  playClip(name, { practice = false } = {}) {
    return new Promise((resolve) => {
      const sound = this.player;
      const done = () => {
        sound.removeEventListener("ended", done);
        sound.removeEventListener("error", failed);
        this.finishClip = null;
        resolve();
      };
      const failed = () => {
        this.clipFailed = true;
        this.renderStatus();
        setTimeout(done, CLIP_FAILURE_GRACE_MS);
      };
      this.finishClip = done;
      sound.addEventListener("ended", done);
      sound.addEventListener("error", failed);
      sound.src = this.clipUrl(name);
      if (practice) applyAudioRate(sound);
      else {
        sound.defaultPlaybackRate = 1;
        sound.playbackRate = 1;
      }
      sound.play().catch(failed);
    });
  }

  halt() {
    this.run = null;
    this.player.pause();
    this.finishClip?.();
    clearInterval(this.waiter);
    this.waitDone?.();
  }

  wait(seconds) {
    return new Promise((resolve) => {
      const until = Date.now() + seconds * 1000;
      this.waitDone = () => {
        clearInterval(this.waiter);
        this.waitDone = null;
        resolve();
      };
      const update = () => {
        this.remaining = secondsLeft(until);
        this.renderStatus();
        if (this.remaining <= 0) this.waitDone?.();
      };
      this.waiter = setInterval(update, 250);
      update();
    });
  }

  async runFrom(index) {
    const run = {};
    this.run = run;
    const steps = this.steps();
    for (let i = index; i < steps.length; i += 1) {
      if (this.run !== run) return;
      const step = steps[i];
      this.state.step = i;
      this.save();
      const spoken = this.speaking;
      this.current = step;
      this.speaking = this.itemSpoken(step);
      this.clipFailed = false;
      this.follow(step);
      if (spoken !== this.speaking && step.group === this.state.view)
        this.renderGroup();
      this.renderStatus();
      if (step.kind === "clip") {
        this.preload(nextClipAfter(steps, i));
        await this.playClip(step.clip);
      } else if (step.kind === "pause" || step.kind === "answer") {
        await this.wait(step.seconds);
      } else if (step.kind === "lock") {
        if (!this.state.locked.includes(step.group))
          this.state.locked.push(step.group);
        this.save();
        this.renderGroup();
      }
    }
    if (this.run === run) this.finish();
  }

  itemSpoken(step) {
    if (step.kind !== "clip" || step.group === null) return null;
    const timeline = this.groups[step.group].group.timeline || [];
    return timeline.find((entry) => entry.clip === step.clip)?.n ?? null;
  }

  playingGroup(step) {
    if (!step) return null;
    if (step.phase === "closing") return this.followed ?? this.state.view;
    if (step.group !== null && step.group !== undefined) return step.group;
    if (step.part === null || step.part === undefined) return 0;
    return this.groups.findIndex((entry) => entry.partIndex === step.part);
  }

  follow(step) {
    const group = this.playingGroup(step);
    if (group === this.followed) return;
    const previous = this.followed;
    this.followed = group;
    if (
      this.state.adaptive ||
      previous === undefined ||
      previous === null ||
      this.state.view === previous
    ) {
      this.state.view = group;
      this.renderGroup();
    } else {
      this.renderChip();
    }
  }

  practiceRate() {
    if (this.state?.mode === "practice" || this.state?.finished)
      applyAudioRate(this.player);
  }

  async playGroup(index) {
    this.halt();
    const run = {};
    this.run = run;
    this.playingIndex = index;
    this.refreshPlayButtons();
    for (const name of this.groups[index].group.clips || []) {
      if (this.run !== run) break;
      await this.playClip(name, { practice: true });
    }
    if (this.run === run) {
      this.run = null;
      this.playingIndex = null;
      this.refreshPlayButtons();
    }
  }

  async playIntro(partIndex) {
    this.halt();
    const run = {};
    this.run = run;
    for (const name of this.bundle.parts[partIndex].intro?.clips || []) {
      if (this.run !== run) break;
      await this.playClip(name, { practice: true });
    }
    if (this.run === run) this.run = null;
  }

  stopPlayback() {
    this.halt();
    this.playingIndex = null;
    this.refreshPlayButtons();
  }

  refreshPlayButtons() {
    if (this.state?.finished) this.renderReviewButtons();
    else this.renderGroup();
  }

  canView(index) {
    if (!this.state.adaptive) return true;
    return index === this.state.view;
  }

  view(index) {
    if (index < 0 || index >= this.groups.length || !this.canView(index))
      return;
    if (this.state.mode === "practice" && this.listening) this.stopPlayback();
    this.state.view = index;
    this.save();
    this.renderGroup();
    this.groupNode?.scrollIntoView({ block: "nearest" });
  }

  groupLocked(index) {
    return this.state.locked.includes(index);
  }

  choose(n, letter) {
    const index = this.groups.findIndex((entry) => entry.numbers.includes(n));
    if (this.groupLocked(index) || this.state.revealed.includes(n)) return;
    this.state.answers[String(n)] = letter;
    this.save();
    this.renderGroup();
    this.renderStatus();
  }

  reveal(n) {
    if (!this.state.revealed.includes(n)) this.state.revealed.push(n);
    this.save();
    this.renderGroup();
  }

  askFinish() {
    this.confirming = true;
    this.renderStatus();
  }

  keepGoing() {
    this.confirming = false;
    this.renderStatus();
  }

  finish() {
    if (!this.state || this.state.finished) return;
    this.halt();
    clearInterval(this.ticker);
    this.releaseWakeLock();
    this.state.finished = true;
    writeStore(attemptKey(this.slugValue), null);

    const outcome = mark(this.bundle, this.state.answers);
    const scale = scaled(this.bundle.scale, outcome.raw);
    this.outcome = outcome;
    this.scale = scale;
    remember(this.slugValue, {
      at: Date.now(),
      mode: this.state.mode,
      adaptive: this.state.adaptive,
      raw: outcome.raw,
      total: outcome.total,
      scale: scale?.score ?? null,
      max: scale?.max ?? null,
      level: scale?.level ?? null,
    });
    if (!this.recordValue && this.saveValue)
      keepPending(this.slugValue, this.state.answers);

    this.toggle(this.stageTarget, false);
    this.stageTarget.replaceChildren();
    this.toggle(this.resultTarget, true);
    this.renderResult();
    this.renderHistory();
    this.resultTarget.scrollIntoView({ block: "start" });
    this.submit();
  }

  async post(answers) {
    const response = await fetch(this.recordValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": csrfToken(),
      },
      body: JSON.stringify({ answers }),
      credentials: "same-origin",
    });
    if (!response.ok) throw new Error(String(response.status));
    return response.json();
  }

  async submit() {
    if (!this.recordValue) return;
    try {
      const payload = await this.post(this.state.answers);
      this.recordNote(
        this.t("saved", { best: payload.best, total: payload.total }),
        false,
      );
    } catch {
      this.recordNote(this.t("save_failed"), true);
    }
  }

  async handOver() {
    if (!this.recordValue || !this.hasHandoverTarget) return;
    const answers = takePending(this.slugValue);
    if (!answers) return;

    const node = this.handoverTarget;
    try {
      const payload = await this.post(answers);
      node.textContent = this.t("door_saved", {
        score: payload.score,
        best: payload.best,
        total: payload.total,
      });
      node.className =
        "rounded-xl border border-emerald-500/50 px-4 py-3 text-sm text-emerald-800 dark:text-emerald-300";
    } catch {
      keepPending(this.slugValue, answers);
      node.textContent = this.t("door_save_failed");
      node.className = "rounded-xl border border-amber-400 px-4 py-3 text-sm";
    }
    node.hidden = false;
  }

  recordNote(text, failed) {
    if (!this.recordNode) return;
    this.recordNode.textContent = text;
    this.recordNode.className = failed
      ? "text-sm text-amber-700 dark:text-amber-400"
      : "text-sm text-emerald-700 dark:text-emerald-400";
  }

  again() {
    this.state = null;
    this.toggle(this.resultTarget, false);
    this.resultTarget.replaceChildren();
    this.toggle(this.setupTarget, true);
    this.offerResume();
    this.setupTarget.scrollIntoView({ block: "start" });
  }

  openZoom(sources) {
    this.zoomFrameTarget.replaceChildren(
      ...sources.map((src) =>
        h("img", { src, alt: "", class: "block h-auto max-w-full" }),
      ),
    );
    this.zoomTarget.showModal();
  }

  toggleZoom() {
    for (const image of this.zoomFrameTarget.querySelectorAll("img"))
      for (const name of ZOOMED) image.classList.toggle(name);
  }

  closeZoom() {
    this.zoomTarget.close();
  }

  renderStage() {
    this.statusNode = h("div");
    this.chipNode = h("div");
    this.groupNode = h("section");
    this.navNode = h("div");
    this.stageTarget.replaceChildren(
      this.statusNode,
      this.chipNode,
      this.groupNode,
      this.navNode,
    );
    this.followed = undefined;
    this.renderStatus();
    this.renderGroup();
  }

  answeredCount() {
    return Object.keys(this.state.answers).length;
  }

  statusText() {
    if (!this.examListening() || !this.current) return null;
    if (this.clipFailed) return this.t("audio_error");
    const step = this.current;
    const seconds = this.remaining ?? step.seconds;
    if (step.kind === "pause") return this.t("pause", { seconds });
    if (step.kind === "answer") return this.t("answer_window", { seconds });
    if (step.kind === "lock") return this.t("locked");
    if (step.phase === "opening") return this.t("opening");
    if (step.phase === "closing") return this.t("closing");
    if (step.phase === "intro")
      return `${this.t("part", { n: this.bundle.parts[step.part].id })} · ${this.t("instructions")}`;
    const numbers = this.groups[step.group].numbers;
    const label =
      this.speaking !== null && numbers.length > 1
        ? this.t("question", { n: this.speaking })
        : this.questionsLabel(numbers);
    return step.plays > 1
      ? `${label} · ${this.t("play_of", { n: step.play, total: step.plays })}`
      : label;
  }

  questionsLabel(numbers) {
    if (numbers.length === 1) return this.t("question", { n: numbers[0] });
    return this.t("questions_range", {
      from: numbers[0],
      to: numbers[numbers.length - 1],
    });
  }

  renderStatus() {
    if (!this.statusNode || !this.state || this.state.finished) return;
    const badge = h("span", {
      class:
        "rounded-full border border-border px-2 py-0.5 text-xs font-medium",
      text: this.modeLabel(this.state),
    });
    const answered = h("span", {
      class: "text-xs tabular-nums text-muted-foreground",
      text: this.t("answered", {
        count: this.answeredCount(),
        total: this.bundle.count,
      }),
    });
    const parts = [badge, answered];
    if (this.state.deadline) {
      const left = secondsLeft(this.state.deadline);
      parts.push(
        h("span", {
          class: `ml-auto text-lg font-bold tabular-nums ${left <= 60 ? "text-red-600" : ""}`,
          role: "timer",
          text: clock(left),
        }),
      );
    }
    const status = this.statusText();
    const finishButton = h("button", {
      type: "button",
      class: `${this.state.deadline ? "" : "ml-auto "}min-h-11 rounded-lg border border-border px-3 text-sm font-medium hover:bg-muted md:min-h-9`,
      "data-exam-hand-in": "",
      text: this.t("finish"),
      onclick: () => this.askFinish(),
    });
    const row = h(
      "div",
      { class: "flex flex-wrap items-center gap-2" },
      parts,
      finishButton,
    );
    const live = status
      ? h("p", {
          class: "text-sm font-medium",
          "aria-live": "polite",
          "data-exam-status": this.current?.kind || "",
          text: status,
        })
      : null;
    const confirm = this.confirming
      ? h(
          "div",
          {
            class:
              "flex flex-wrap items-center gap-2 rounded-lg border border-amber-400 bg-amber-500/10 px-3 py-2 text-sm",
          },
          h("span", {
            class: "min-w-0 flex-1",
            text: this.t("finish_confirm", {
              count: this.bundle.count - this.answeredCount(),
            }),
          }),
          h("button", {
            type: "button",
            class:
              "min-h-11 rounded-lg bg-primary px-3 text-sm font-semibold text-primary-foreground hover:opacity-90 md:min-h-9",
            "data-exam-finish": "",
            text: this.t("finish_yes"),
            onclick: () => this.finish(),
          }),
          h("button", {
            type: "button",
            class:
              "min-h-11 rounded-lg border border-border px-3 text-sm font-medium hover:bg-muted md:min-h-9",
            text: this.t("finish_no"),
            onclick: () => this.keepGoing(),
          }),
        )
      : null;
    this.statusNode.className =
      "sticky top-14 z-20 -mx-4 space-y-2 border-b border-border bg-background/95 px-4 py-2 backdrop-blur md:top-[6.1rem]";
    this.statusNode.replaceChildren(...[row, live, confirm].filter(Boolean));
  }

  renderChip() {
    if (!this.chipNode) return;
    const playing = this.followed;
    if (
      !this.examListening() ||
      playing === null ||
      playing === undefined ||
      playing === this.state.view
    ) {
      this.chipNode.replaceChildren();
      return;
    }
    this.chipNode.replaceChildren(
      h(
        "div",
        {
          class:
            "flex items-center gap-2 rounded-lg border border-primary/40 bg-primary/10 px-3 py-2 text-sm",
        },
        h("span", {
          class: "min-w-0 flex-1",
          text: this.t("now_playing", {
            label: this.questionsLabel(this.groups[playing].numbers),
          }),
        }),
        h("button", {
          type: "button",
          class:
            "min-h-11 rounded-lg border border-border bg-card px-3 text-sm font-medium hover:bg-muted md:min-h-9",
          text: this.t("go"),
          onclick: () => this.view(playing),
        }),
      ),
    );
  }

  pictures(piece) {
    const paths = piece?.images?.length ? piece.images : [piece?.image];
    return paths.filter(Boolean).map((path) => this.imageUrl(path));
  }

  zoomButton(piece, label) {
    return h("button", {
      type: "button",
      class:
        "min-h-11 shrink-0 rounded-md px-2 text-xs font-medium text-primary underline underline-offset-2 md:min-h-8",
      text: label,
      onclick: (event) => {
        event.stopPropagation();
        this.openZoom(this.pictures(piece));
      },
    });
  }

  content(piece, { large = false, inert = false } = {}) {
    if (!piece) return null;
    const nodes = [];
    if (piece.text) {
      nodes.push(
        h(
          "div",
          {
            class: `space-y-1 break-words ${large ? "text-lg leading-relaxed" : "text-base leading-relaxed"}`,
            lang: "zh-TW",
          },
          String(piece.text)
            .split("\n")
            .filter((line) => line.trim())
            .map((line) => h("p", { text: line })),
        ),
      );
      if (piece.image && !inert)
        nodes.push(this.zoomButton(piece, this.t("original")));
    } else if (piece.image && inert) {
      nodes.push(
        this.pictures(piece).map((src) =>
          h("img", {
            src,
            alt: "",
            class: "block h-auto max-w-full rounded-md bg-white",
            decoding: "async",
          }),
        ),
      );
    } else if (piece.image) {
      const sources = this.pictures(piece);
      nodes.push(
        h(
          "button",
          {
            type: "button",
            class:
              "block max-w-full space-y-1 overflow-hidden rounded-md border border-border bg-white",
            "aria-label": this.t("zoom"),
            onclick: (event) => {
              event.stopPropagation();
              this.openZoom(sources);
            },
          },
          sources.map((src) =>
            h("img", {
              src,
              alt: "",
              class: "block h-auto max-w-full",
              decoding: "async",
            }),
          ),
        ),
      );
    }
    return nodes.length
      ? h("div", { class: "min-w-0 space-y-1" }, nodes)
      : null;
  }

  sharedOptions(group) {
    if (!group.options_shared) return null;
    const options = group.items[0]?.options || [];
    return h(
      "div",
      { class: "grid gap-2 rounded-xl border border-border bg-muted/40 p-3" },
      options.map((option) =>
        h(
          "div",
          { class: "flex min-w-0 items-center gap-2" },
          h("span", {
            class:
              "inline-flex size-8 shrink-0 items-center justify-center rounded-full border border-border text-sm font-semibold",
            text: option.k,
          }),
          this.content(option),
        ),
      ),
    );
  }

  optionsBare(item) {
    return item.options.every((option) => !option.text && !option.image);
  }

  optionNodes(item, { review = false } = {}) {
    const n = item.n;
    const chosen = this.state.answers[String(n)] ?? null;
    const expected = this.bundle.key?.[String(n)] ?? null;
    const shown = review || this.state.revealed.includes(n);
    const index = this.groups.findIndex((entry) => entry.numbers.includes(n));
    const frozen = review || shown || this.groupLocked(index);
    const bare =
      this.optionsBare(item) ||
      Boolean(this.groups[index].group.options_shared);

    const nodes = item.options.map((option) => {
      const selected = chosen === option.k;
      const right = shown && option.k === expected;
      const wrong = shown && selected && option.k !== expected;
      const tone = right
        ? "border-emerald-500 bg-emerald-500/10"
        : wrong
          ? "border-red-500 bg-red-500/10"
          : selected
            ? "border-primary bg-primary/10"
            : "border-border bg-card hover:bg-muted";
      const letter = h("span", {
        class: `inline-flex size-8 shrink-0 items-center justify-center rounded-full border text-sm font-semibold ${selected ? "border-primary bg-primary text-primary-foreground" : "border-border"}`,
        text: option.k,
      });
      const marks = [];
      if (right)
        marks.push(
          h("span", {
            class:
              "ml-auto shrink-0 text-xs font-medium text-emerald-700 dark:text-emerald-400",
            text: this.t("correct_answer"),
          }),
        );
      if (wrong || (review && selected && !right))
        marks.push(
          h("span", {
            class:
              "ml-auto shrink-0 text-xs font-medium text-red-700 dark:text-red-400",
            text: this.t("your_answer"),
          }),
        );
      const choice = h(
        "button",
        {
          type: "button",
          role: "radio",
          "aria-checked": String(selected),
          "data-exam-option": `${n}${option.k}`,
          disabled: frozen,
          class: `flex min-h-11 min-w-0 items-center gap-2 rounded-lg border px-2 py-1.5 text-left ${bare ? "" : "flex-1"} ${tone} ${frozen ? "cursor-default" : "cursor-pointer"}`,
          onclick: () => this.choose(n, option.k),
        },
        letter,
        bare ? null : this.content(option, { inert: true }),
        marks,
      );
      if (bare || !option.image) return choice;
      return h(
        "div",
        { class: "flex items-center gap-1" },
        choice,
        this.zoomButton(
          option,
          option.text ? this.t("original") : this.t("zoom"),
        ),
      );
    });

    return h(
      "div",
      {
        class: bare ? "flex flex-wrap gap-2" : "grid gap-2",
        role: "radiogroup",
        "aria-label": this.t("question", { n }),
      },
      nodes,
    );
  }

  itemNode(item, { review = false } = {}) {
    const n = item.n;
    const children = [
      h("div", {
        class: "text-xs font-semibold tabular-nums text-muted-foreground",
        text: this.t("question", { n }),
      }),
      this.content(item.stem, { large: true }),
      this.optionNodes(item, { review }),
    ];
    if (review) {
      const given = this.state.answers[String(n)];
      if (!given)
        children.push(
          h("p", {
            class: "text-xs font-medium text-red-700 dark:text-red-400",
            text: this.t("no_answer"),
          }),
        );
      if (this.state.revealed.includes(n))
        children.push(
          h("p", {
            class: "text-xs text-muted-foreground",
            text: this.t("revealed"),
          }),
        );
    } else if (
      this.state.mode === "practice" &&
      !this.state.revealed.includes(n)
    ) {
      children.push(
        h("button", {
          type: "button",
          class:
            "min-h-11 rounded-lg border border-border px-3 text-sm font-medium hover:bg-muted md:min-h-9",
          "data-exam-reveal": String(n),
          text: this.t("check"),
          onclick: () => this.reveal(n),
        }),
      );
    }
    return h(
      "div",
      {
        class: `space-y-3 rounded-xl border bg-card p-3 sm:p-4 ${!review && this.examListening() && this.speaking === n ? "border-primary ring-2 ring-primary/40" : "border-border"}`,
        id: `exam-q${n}`,
      },
      children,
    );
  }

  introContent(intro) {
    const language = this.bundle.edition || "en";
    if (language === "ja" && intro.image)
      return this.content({ image: intro.image, images: intro.images });
    if (!intro.text) return this.content(intro);

    const runs = String(intro.text)
      .split("\n")
      .filter((line) => line.trim())
      .map((line) =>
        h(
          "p",
          { lang: language },
          line
            .split(MANDARIN_RUN)
            .filter(Boolean)
            .map((run) =>
              MANDARIN_RUN.test(run)
                ? h("span", { lang: "zh-TW", text: run })
                : document.createTextNode(run),
            ),
        ),
      );
    return h(
      "div",
      { class: "min-w-0 space-y-1" },
      h(
        "div",
        {
          class: "space-y-1 break-words text-base leading-relaxed",
          lang: language,
        },
        runs,
      ),
      intro.image ? this.zoomButton(intro, this.t("original")) : null,
    );
  }

  partHeader(entry, { withIntro }) {
    const part = entry.part;
    const header = h(
      "div",
      { class: "flex flex-wrap items-baseline gap-x-2" },
      h("span", {
        class:
          "text-xs font-semibold uppercase tracking-wide text-muted-foreground",
        text: this.t("part", { n: part.id }),
      }),
      h("span", {
        class: "text-sm font-medium",
        lang: "zh-TW",
        text: partTitle(part.title),
      }),
    );
    if (!withIntro || !part.intro || (!part.intro.text && !part.intro.image))
      return header;
    const playIntro =
      this.listening &&
      (this.state.mode === "practice" || this.state.finished) &&
      part.intro.clips?.length
        ? h("button", {
            type: "button",
            class:
              "min-h-11 rounded-lg border border-border px-3 text-sm font-medium hover:bg-muted md:min-h-9",
            text: this.t("play"),
            onclick: () => this.playIntro(entry.partIndex),
          })
        : null;
    return h(
      "div",
      { class: "space-y-2" },
      header,
      h(
        "details",
        {
          class: "rounded-lg border border-border px-3 py-2",
          open: this.examListening() && this.current?.phase === "intro",
        },
        h("summary", {
          class: "cursor-pointer text-sm font-medium",
          text: this.t("instructions"),
        }),
        h(
          "div",
          { class: "mt-2 space-y-2" },
          this.introContent(part.intro),
          playIntro,
        ),
      ),
    );
  }

  playButton(index) {
    const playing = this.playingIndex === index && this.run;
    return h("button", {
      type: "button",
      class:
        "inline-flex min-h-11 items-center gap-2 rounded-lg bg-primary px-4 text-sm font-semibold text-primary-foreground hover:opacity-90 md:min-h-9",
      "data-exam-play": String(index),
      text: playing ? this.t("stop") : this.t("play"),
      onclick: () => (playing ? this.stopPlayback() : this.playGroup(index)),
    });
  }

  renderGroup() {
    if (!this.groupNode || !this.state || this.state.finished) return;
    const index = this.state.view;
    const entry = this.groups[index];
    const first = this.groups.findIndex(
      (candidate) => candidate.partIndex === entry.partIndex,
    );
    const locked = this.groupLocked(index);

    const children = [this.partHeader(entry, { withIntro: first === index })];
    if (this.listening && this.state.mode === "practice")
      children.push(h("div", {}, this.playButton(index)));
    children.push(this.content(entry.group.context, { large: true }));
    children.push(this.sharedOptions(entry.group));
    if (locked)
      children.push(
        h("p", {
          class: "text-xs font-medium text-muted-foreground",
          text: this.t("locked"),
        }),
      );
    children.push(entry.group.items.map((item) => this.itemNode(item)));

    this.groupNode.className = "space-y-3";
    this.groupNode.replaceChildren(...children.flat(Infinity).filter(Boolean));
    this.renderChip();
    this.renderNav();
  }

  renderNav() {
    if (!this.navNode) return;
    const index = this.state.view;
    const free = !this.state.adaptive;
    const stepper = free
      ? h(
          "div",
          { class: "flex items-center justify-between gap-2" },
          h("button", {
            type: "button",
            class:
              "min-h-11 rounded-lg border border-border px-4 text-sm font-medium hover:bg-muted disabled:opacity-40 md:min-h-9",
            disabled: index === 0,
            text: this.t("previous"),
            onclick: () => this.view(index - 1),
          }),
          h("button", {
            type: "button",
            class:
              "min-h-11 rounded-lg border border-border px-4 text-sm font-medium hover:bg-muted disabled:opacity-40 md:min-h-9",
            "data-exam-next": "",
            disabled: index === this.groups.length - 1,
            text: this.t("next"),
            onclick: () => this.view(index + 1),
          }),
        )
      : null;

    const cells = this.groups.flatMap((entry) =>
      entry.numbers.map((n) => {
        const answered = Boolean(this.state.answers[String(n)]);
        const current = entry.index === index;
        const revealed = this.state.revealed.includes(n);
        const correct =
          revealed &&
          this.state.answers[String(n)] === this.bundle.key?.[String(n)];
        const tone = revealed
          ? correct
            ? "border-emerald-500 bg-emerald-500/15"
            : "border-red-500 bg-red-500/15"
          : answered
            ? "border-primary bg-primary text-primary-foreground"
            : "border-border bg-card";
        return h("button", {
          type: "button",
          class: `h-9 min-w-0 rounded-md border text-xs font-medium tabular-nums ${tone} ${current ? "ring-2 ring-primary ring-offset-1 ring-offset-background" : ""} disabled:opacity-60`,
          disabled: !free,
          "aria-current": current ? "true" : null,
          text: String(n),
          onclick: () => this.view(entry.index),
        });
      }),
    );

    this.navNode.className = "space-y-3";
    this.navNode.replaceChildren(
      ...[
        stepper,
        h("div", { class: "grid grid-cols-10 gap-1" }, cells),
      ].filter(Boolean),
    );
  }

  renderResult() {
    const outcome = this.outcome;
    const scale = this.scale;
    const summary = [
      h("h2", { class: "text-xl font-bold", text: this.t("result_title") }),
      h("p", {
        class: "text-3xl font-bold tabular-nums",
        "data-exam-raw": String(outcome.raw),
        text: `${outcome.raw} / ${outcome.total}`,
      }),
      h("p", {
        class: "text-sm text-muted-foreground",
        text: this.t("raw", { score: outcome.raw, total: outcome.total }),
      }),
    ];
    if (scale) {
      const score = scale.score ?? "—";
      summary.push(
        h("p", {
          class: "text-base font-semibold tabular-nums",
          "data-exam-scale": String(score),
          text:
            scale.max !== null
              ? this.t("scale", { score, max: scale.max })
              : this.t("scale_only", { score }),
        }),
      );
      if (scale.leveled)
        summary.push(
          h("p", {
            class: "text-base font-semibold",
            "data-exam-level": scale.level || "",
            text: scale.level
              ? this.t("level", { level: this.levelName(scale.level) })
              : this.t("no_level"),
          }),
        );
      if (scale.leveled && this.publishedLevels)
        summary.push(
          h("p", {
            class: "text-xs text-muted-foreground",
            text: this.t("level_source"),
          }),
        );
    } else {
      summary.push(
        h("p", {
          class: "text-xs text-muted-foreground",
          text: this.t("no_scale"),
        }),
      );
    }
    this.recordNode = h("p", {
      class: "text-sm text-muted-foreground",
      text: this.recordValue || this.saveValue ? "" : this.t("device_note"),
    });
    summary.push(this.recordNode);
    if (!this.recordValue && this.saveValue)
      summary.push(
        h(
          "div",
          {
            class:
              "space-y-2 rounded-xl border border-primary/40 bg-primary/5 px-4 py-3",
            "data-exam-save": "",
          },
          h("p", { class: "text-sm", text: this.t("door_save_body") }),
          h("a", {
            href: this.saveValue,
            "data-turbo": "false",
            class:
              "inline-flex min-h-11 items-center rounded-lg bg-primary px-4 text-sm font-semibold text-primary-foreground hover:opacity-90 md:min-h-9",
            text: this.t("door_save_cta"),
          }),
        ),
      );

    const parts = h(
      "div",
      { class: "space-y-2" },
      h("h3", {
        class:
          "text-sm font-semibold uppercase tracking-wide text-muted-foreground",
        text: this.t("by_part"),
      }),
      outcome.parts.map((part) =>
        h(
          "div",
          { class: "space-y-1" },
          h(
            "div",
            { class: "flex items-baseline justify-between gap-3 text-sm" },
            h(
              "span",
              { class: "min-w-0" },
              h("span", {
                class: "font-medium",
                text: this.t("part", { n: part.id }),
              }),
              partTitle(part.title)
                ? h("span", {
                    lang: "zh-TW",
                    text: ` · ${partTitle(part.title)}`,
                  })
                : null,
            ),
            h("span", {
              class: "shrink-0 tabular-nums",
              text: `${part.correct} / ${part.total}`,
            }),
          ),
          h(
            "div",
            { class: "h-2 overflow-hidden rounded-full bg-muted" },
            h("div", {
              class: "h-full rounded-full bg-emerald-500",
              style: `width: ${part.total ? Math.round((part.correct * 100) / part.total) : 0}%`,
            }),
          ),
        ),
      ),
    );

    const actions = h(
      "div",
      { class: "flex flex-wrap gap-2" },
      h("button", {
        type: "button",
        class:
          "min-h-11 rounded-lg bg-primary px-4 text-sm font-semibold text-primary-foreground hover:opacity-90 md:min-h-9",
        text: this.t("again"),
        onclick: () => this.again(),
      }),
      h("a", {
        href: this.indexValue,
        class:
          "inline-flex min-h-11 items-center rounded-lg border border-border px-4 text-sm font-medium hover:bg-muted md:min-h-9",
        text: this.t("all_papers"),
      }),
    );

    this.reviewNode = h("div", { class: "space-y-4" });
    this.renderReview();

    this.resultTarget.replaceChildren(
      h(
        "div",
        { class: "space-y-3 rounded-2xl border border-border bg-card p-4" },
        summary,
      ),
      h(
        "div",
        { class: "rounded-2xl border border-border bg-card p-4" },
        parts,
      ),
      actions,
      h(
        "section",
        { class: "space-y-3" },
        h("h3", { class: "text-lg font-semibold", text: this.t("review") }),
        this.reviewNode,
      ),
    );
  }

  renderReview() {
    let lastPart = null;
    const blocks = this.groups.map((entry) => {
      const children = [];
      if (entry.partIndex !== lastPart) {
        lastPart = entry.partIndex;
        children.push(this.partHeader(entry, { withIntro: false }));
      }
      if (this.listening)
        children.push(h("div", {}, this.playButton(entry.index)));
      children.push(this.content(entry.group.context, { large: true }));
      children.push(this.sharedOptions(entry.group));
      if (this.listening && entry.group.transcript)
        children.push(
          h(
            "details",
            { class: "rounded-lg border border-border px-3 py-2" },
            h("summary", {
              class: "cursor-pointer text-sm font-medium",
              text: this.t("transcript"),
            }),
            h(
              "div",
              {
                class: "mt-2 space-y-1 text-base leading-relaxed",
                lang: "zh-TW",
              },
              String(entry.group.transcript)
                .split("\n")
                .filter((line) => line.trim())
                .map((line) => h("p", { text: line })),
            ),
          ),
        );
      children.push(
        entry.group.items.map((item) => this.itemNode(item, { review: true })),
      );
      return h(
        "div",
        { class: "space-y-3", "data-exam-review-group": String(entry.index) },
        children.filter(Boolean),
      );
    });
    this.reviewNode.replaceChildren(...blocks);
  }

  renderReviewButtons() {
    if (!this.reviewNode) return;
    for (const button of this.reviewNode.querySelectorAll("[data-exam-play]")) {
      const index = Number(button.dataset.examPlay);
      button.replaceWith(this.playButton(index));
    }
  }

  renderHistory() {
    if (!this.hasHistoryTarget) return;
    const entries = history()[this.slugValue] || [];
    if (!entries.length) {
      this.historyTarget.hidden = true;
      return;
    }
    const top = best(entries);
    const list = h(
      "ul",
      { class: "space-y-1 text-sm" },
      entries.slice(0, 5).map((entry) =>
        h(
          "li",
          { class: "flex flex-wrap items-baseline gap-x-3" },
          h("span", {
            class: "tabular-nums text-muted-foreground",
            text: new Date(entry.at).toLocaleDateString(
              document.documentElement.lang || undefined,
            ),
          }),
          h("span", { text: this.modeLabel(entry) }),
          h("span", {
            class: `font-semibold tabular-nums ${entry === top ? "text-emerald-700 dark:text-emerald-400" : ""}`,
            text: `${entry.raw}/${entry.total}`,
          }),
          entry.scale !== null && entry.scale !== undefined
            ? h("span", {
                class: "tabular-nums text-muted-foreground",
                text: entry.level
                  ? `${entry.scale} · ${this.levelName(entry.level)}`
                  : String(entry.scale),
              })
            : null,
        ),
      ),
    );
    this.historyTarget.hidden = false;
    this.historyTarget.replaceChildren(
      h("h2", {
        class:
          "text-sm font-semibold uppercase tracking-wide text-muted-foreground",
        text: this.t("history"),
      }),
      list,
    );
  }
}

const SILENCE =
  "data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQAAAAA=";
