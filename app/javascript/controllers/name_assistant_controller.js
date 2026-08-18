import { Controller } from "@hotwired/stimulus";

const VOWELS = "aeiouv";
const COHORTS = ["elder", "middle", "young", "recent"];
const WANTED = 5;
const COMMON_CONTOUR = 0.03;
const STRONG_PAIR = 1;
const RARE_RATE = 0.08;
const MALE_LEAN = 0.7;
const FEMALE_LEAN = 0.3;

export default class extends Controller {
  static values = { url: String };
  static targets = [
    "surname",
    "given",
    "cohort",
    "gender",
    "field",
    "length",
    "strokes",
    "rarity",
    "closeness",
    "official",
    "results",
    "note",
    "status",
    "form",
  ];

  connect() {
    this.ready = false;
    this.russian = String(document.documentElement.lang || "").startsWith("ru");
    this.copy = this.readCopy();
    this.load();
  }

  readCopy() {
    try {
      return JSON.parse(this.element.dataset.copy || "{}");
    } catch {
      return {};
    }
  }

  async load() {
    try {
      const response = await fetch(this.urlValue);
      if (!response.ok) throw new Error(response.status);
      this.stats = await response.json();
      this.ready = true;
      this.statusTarget.hidden = true;
      this.formTarget.hidden = false;
    } catch {
      this.statusTarget.dataset.failed = "true";
    }
  }

  gloss(character) {
    const russian = this.russian ? character.ru : null;
    return russian || character.en || "";
  }

  syllables(text) {
    const clean = String(text || "")
      .toLowerCase()
      .replace(/[^a-z]/g, "");
    if (!clean) return [];
    const parts = clean.match(
      /[^aeiouv]*[aeiouv]+[^aeiouv]*?(?=[^aeiouv]*[aeiouv]|$)/g,
    );
    return parts || [clean];
  }

  bare(pinyin) {
    return String(pinyin || "")
      .normalize("NFD")
      .replace(/[̀-ͯ]/g, "")
      .replace(/[^a-z]/gi, "")
      .toLowerCase();
  }

  similarity(a, b) {
    if (!a || !b) return 0;
    if (a === b) return 1;
    const onsetA = a.split("").findIndex((c) => VOWELS.includes(c));
    const onsetB = b.split("").findIndex((c) => VOWELS.includes(c));
    const headA = onsetA <= 0 ? "" : a.slice(0, onsetA);
    const headB = onsetB <= 0 ? "" : b.slice(0, onsetB);
    const tailA = a.slice(Math.max(onsetA, 0));
    const tailB = b.slice(Math.max(onsetB, 0));
    let score = 0;
    if (headA && headA === headB) score += 0.45;
    else if (headA[0] && headA[0] === headB[0]) score += 0.25;
    else if (!headA && !headB) score += 0.2;
    if (tailA === tailB) score += 0.55;
    else if (tailA[0] === tailB[0]) score += 0.25;
    return score;
  }

  run(event) {
    event?.preventDefault();
    if (!this.ready) return;

    const cohort = this.cohortTarget.value;
    const gender = this.genderTarget.value;
    const fields = [...this.fieldTargets]
      .filter((f) => f.checked)
      .map((f) => f.value);
    const wantLength = Number(this.lengthTarget.value);
    const strokes = this.strokesTarget.value;
    const rarity = this.rarityTarget.value;
    const echo = 1 - Number(this.closenessTarget.value) / 100;
    const official = this.officialTarget.checked;

    const surnames = this.rankSurnames(this.surnameTarget.value, echo);
    const givenSyllables = this.syllables(this.givenTarget.value);
    const chars = this.rankCharacters({
      cohort,
      gender,
      fields,
      strokes,
      rarity,
      official,
      echo,
      givenSyllables,
    });

    this.render(surnames, chars, wantLength, { cohort, echo, official });
  }

  rankSurnames(latin, echo) {
    const target = this.syllables(latin)[0] || "";
    return this.stats.surnames
      .map((row) => {
        const sound = this.similarity(target, this.bare(row.pinyin));
        const common = Math.min(row.share * 12, 1);
        return {
          ...row,
          sound,
          score: sound * (0.35 + echo * 0.65) + common * (1 - echo) * 0.5,
        };
      })
      .filter((row) => row.score > 0.08)
      .sort((a, b) => b.score - a.score)
      .slice(0, 8);
  }

  rankCharacters({
    cohort,
    gender,
    fields,
    strokes,
    rarity,
    official,
    echo,
    givenSyllables,
  }) {
    const maxRate = Math.max(
      ...this.stats.characters.map((c) => c.cohorts?.[cohort] || 0),
      1,
    );
    return this.stats.characters
      .filter((c) => {
        if (official && !c.strokes) return false;
        if (gender !== "any" && c.lean !== null && c.lean !== undefined) {
          if (gender === "male" && c.lean < 0.35) return false;
          if (gender === "female" && c.lean > 0.65) return false;
        }
        return (c.cohorts?.[cohort] || 0) > 0;
      })
      .map((c) => {
        const rate = (c.cohorts?.[cohort] || 0) / maxRate;
        const fieldHit = fields.length
          ? (c.fields || []).filter((f) => fields.includes(f)).length /
            fields.length
          : 0;
        const strokeScore = this.strokePreference(c.strokes, strokes);
        const rarityScore =
          rarity === "unique" ? 1 - rate : rarity === "common" ? rate : 0.5;
        const sound = Math.max(
          ...givenSyllables.map((s) => this.similarity(s, this.bare(c.pinyin))),
          0,
        );
        const score =
          rate * 0.9 +
          fieldHit * 1.1 +
          strokeScore * 0.5 +
          rarityScore * 0.6 +
          sound * echo * 1.4;
        return { ...c, rate, fieldHit, sound, score };
      })
      .sort((a, b) => b.score - a.score)
      .slice(0, 60);
  }

  strokePreference(count, want) {
    if (!count || want === "any") return 0.5;
    if (want === "simple") return count <= 8 ? 1 : count <= 12 ? 0.5 : 0;
    if (want === "complex") return count >= 13 ? 1 : count >= 9 ? 0.5 : 0;
    return 0.5;
  }

  contourShare(tones) {
    const key = tones.join("-");
    const total =
      this.stats.contours.reduce((sum, row) => sum + row.count, 0) || 1;
    const found = this.stats.contours.find((row) => row.text === key);
    return found ? found.count / total : 0;
  }

  buildGiven(chars, wantLength) {
    if (wantLength === 1)
      return chars
        .slice(0, 12)
        .map((c) => ({ chars: [c], pmi: null, score: c.score }));

    const firsts = chars.filter((c) => c.first >= c.second).slice(0, 14);
    const seconds = chars.filter((c) => c.second > c.first).slice(0, 14);
    const pmiMap = new Map(this.stats.pairs.map((p) => [p.text, p.pmi]));
    const out = [];
    for (const a of firsts) {
      for (const b of seconds) {
        if (a.text === b.text) continue;
        const pmi = pmiMap.get(a.text + b.text);
        const repeat = a.tone && a.tone === b.tone ? -0.9 : 0;
        out.push({
          chars: [a, b],
          pmi,
          score: a.score + b.score + (pmi ? pmi * 0.25 : 0) + repeat,
        });
      }
    }
    return out.sort((x, y) => y.score - x.score).slice(0, 40);
  }

  peakCohort(character) {
    let best = 0;
    let rate = -1;
    COHORTS.forEach((name, index) => {
      const value = character.cohorts?.[name] || 0;
      if (value > rate) {
        rate = value;
        best = index;
      }
    });
    return best;
  }

  fill(template, values) {
    return String(template || "").replace(
      /%\{(\w+)\}/g,
      (_, key) => values[key] ?? "",
    );
  }

  reasons(row, context) {
    const copy = this.copy.why || {};
    const vibes = this.copy.vibes || {};
    const chars = row.combo.chars;
    const out = [];

    const owned = chars.map((c) =>
      (c.fields || []).filter((field) => vibes[field]),
    );
    const carriers = chars.filter((_, index) => owned[index].length);
    const all = [...new Set(owned.flat())];
    const shared =
      owned.length > 1 ? owned[0].find((f) => owned[1].includes(f)) : null;

    if (!all.length) out.push(copy.meaning_plain);
    else if (chars.length === 1)
      out.push(this.fill(copy.meaning_solo, { first: vibes[all[0]] }));
    else if (carriers.length === 1)
      out.push(
        this.fill(copy.meaning_single, {
          text: carriers[0].text,
          first: vibes[all[0]],
        }),
      );
    else if (shared)
      out.push(this.fill(copy.meaning_one, { first: vibes[shared] }));
    else
      out.push(
        this.fill(copy.meaning_two, {
          first: vibes[owned[0][0]],
          second: vibes[owned[1][0]],
        }),
      );

    const tones = row.tones.filter(Boolean).join("-");
    if (row.repeated) out.push(copy.sound_repeat);
    else if (row.share >= COMMON_CONTOUR)
      out.push(this.fill(copy.sound_common, { tones }));
    else out.push(this.fill(copy.sound_rare, { tones }));

    if (chars.length > 1)
      out.push(
        row.combo.pmi && row.combo.pmi > STRONG_PAIR
          ? copy.pair_strong
          : copy.pair_fresh,
      );

    const here = COHORTS.indexOf(context.cohort);
    const peaks = chars.map((c) => this.peakCohort(c));
    if (peaks.every((peak) => peak === here)) out.push(copy.era_match);
    else if (peaks.some((peak) => peak > here)) out.push(copy.era_recent);
    else out.push(copy.era_older);

    const rare = chars.find((c) => c.rate < RARE_RATE);
    if (rare) out.push(this.fill(copy.rare_char, { text: rare.text }));

    const leans = chars.map((c) =>
      c.lean === null || c.lean === undefined ? 0.5 : c.lean,
    );
    const lean = leans.reduce((sum, value) => sum + value, 0) / leans.length;
    if (lean >= MALE_LEAN) out.push(copy.gender_male);
    else if (lean <= FEMALE_LEAN) out.push(copy.gender_female);
    else out.push(copy.gender_neutral);

    if (context.echo > 0.5 && chars.some((c) => c.sound > 0.5))
      out.push(copy.echo);
    if (context.official) out.push(copy.official);

    return out.filter(Boolean);
  }

  spread(rows) {
    const out = [];
    const seenGiven = new Set();
    const seenSurname = new Map();
    const seenHead = new Map();

    const take = (row) => {
      const given = row.combo.chars.map((c) => c.text).join("");
      seenGiven.add(given);
      seenSurname.set(
        row.surname.text,
        (seenSurname.get(row.surname.text) || 0) + 1,
      );
      seenHead.set(
        row.combo.chars[0].text,
        (seenHead.get(row.combo.chars[0].text) || 0) + 1,
      );
      out.push(row);
    };

    for (const row of rows) {
      if (out.length >= WANTED) break;
      const given = row.combo.chars.map((c) => c.text).join("");
      if (seenGiven.has(given)) continue;
      if ((seenSurname.get(row.surname.text) || 0) >= 2) continue;
      if ((seenHead.get(row.combo.chars[0].text) || 0) >= 2) continue;
      take(row);
    }

    for (const row of rows) {
      if (out.length >= WANTED) break;
      const given = row.combo.chars.map((c) => c.text).join("");
      if (seenGiven.has(given)) continue;
      if ((seenSurname.get(row.surname.text) || 0) >= 3) continue;
      take(row);
    }

    return out;
  }

  render(surnames, chars, wantLength, context) {
    const given = this.buildGiven(chars, wantLength);
    const labels = this.element.dataset;
    const rows = [];

    for (const surname of surnames.slice(0, 6)) {
      for (const combo of given.slice(0, 18)) {
        const tones = [surname.zhuyin, ...combo.chars.map((c) => c.zhuyin)].map(
          (z) => this.toneOf(z),
        );
        const share = tones.every(Boolean) ? this.contourShare(tones) : 0;
        const repeated = Boolean(tones[1] && tones[1] === tones[2]);
        rows.push({
          surname,
          combo,
          tones,
          share,
          repeated,
          rank: combo.score + share * 20 + surname.score * 0.5,
        });
      }
    }
    rows.sort((a, b) => b.rank - a.rank);

    const chosen = this.spread(rows);

    this.resultsTarget.innerHTML = chosen
      .map((row) => {
        const full =
          row.surname.text + row.combo.chars.map((c) => c.text).join("");
        const pinyin = [
          row.surname.pinyin,
          ...row.combo.chars.map((c) => c.pinyin),
        ].join(" ");
        const meanings = row.combo.chars
          .map((c) => `${c.text} — ${this.escape(this.gloss(c))}`)
          .join("; ");
        const badges = [];
        if (row.combo.pmi)
          badges.push(`${labels.labelPair} ${row.combo.pmi.toFixed(1)}`);
        if (row.share)
          badges.push(
            `${labels.labelContour} ${(row.share * 100).toFixed(1)}%`,
          );
        if (row.repeated) badges.push(labels.labelRepeat);
        const strokes = row.combo.chars.reduce(
          (sum, c) => sum + (c.strokes || 0),
          0,
        );
        if (strokes) badges.push(`${labels.labelStrokes} ${strokes}`);

        const why = this.reasons(row, context)
          .map((line) => `<li>${this.escape(line)}</li>`)
          .join("");

        return `<li class="min-w-0 rounded-xl border border-border bg-card px-4 py-3">
          <div class="flex min-w-0 flex-wrap items-baseline gap-x-3 gap-y-1">
            <span class="text-2xl font-semibold" lang="zh-TW">${full}</span>
            <span class="text-sm text-muted-foreground">${this.escape(pinyin)}</span>
            <span class="text-xs text-muted-foreground tabular-nums">${row.tones.join("-")}</span>
          </div>
          <p class="mt-1 break-words text-sm text-muted-foreground">${meanings}</p>
          <div class="mt-2 flex flex-wrap gap-1 text-xs text-muted-foreground">
            ${badges.map((b) => `<span class="rounded-full bg-muted px-2 py-0.5">${this.escape(b)}</span>`).join("")}
          </div>
          <div class="mt-3 border-t border-border pt-2">
            <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">${this.escape(labels.labelWhy)}</p>
            <ul class="mt-1 list-disc space-y-1 pl-4 text-sm leading-relaxed text-muted-foreground">${why}</ul>
          </div>
        </li>`;
      })
      .join("");

    this.resultsTarget.hidden = chosen.length === 0;
    this.noteTarget.hidden = chosen.length === 0;
  }

  toneOf(zhuyin) {
    const text = String(zhuyin || "").trim();
    if (!text) return null;
    if (text.startsWith("˙")) return 5;
    const marks = { ˊ: 2, ˇ: 3, ˋ: 4 };
    return marks[text.slice(-1)] || 1;
  }

  escape(text) {
    const div = document.createElement("div");
    div.textContent = String(text ?? "");
    return div.innerHTML;
  }
}
