export const ADAPTIVE_SECONDS = 10;
export const HISTORY_KEY = "exams.history";
export const HISTORY_LIMIT = 20;
export const PENDING_KEY = "exams.pending";
export const PENDING_TTL_MS = 24 * 60 * 60 * 1000;

const BARE_PART_TITLE = /^第[一二三四五六七八九十]+部分(?:\s*Part\s+\w+)?$/i;

export const partTitle = (title) =>
  BARE_PART_TITLE.test(String(title || "").trim()) ? "" : String(title || "");

export const attemptKey = (slug) => `exams.attempt.${slug}`;

export function groupsOf(bundle) {
  const groups = [];
  bundle.parts.forEach((part, partIndex) => {
    for (const group of part.groups) {
      groups.push({
        index: groups.length,
        partIndex,
        part,
        group,
        numbers: group.items.map((item) => item.n),
      });
    }
  });
  return groups;
}

export function listeningSchedule(bundle, { adaptive = false } = {}) {
  const steps = [];
  const clip = (name, details) =>
    steps.push({ kind: "clip", clip: name, ...details });

  for (const name of bundle.opening_clips || [])
    clip(name, { phase: "opening", part: null, group: null });

  let groupIndex = 0;
  bundle.parts.forEach((part, partIndex) => {
    for (const name of part.intro?.clips || [])
      clip(name, { phase: "intro", part: partIndex, group: null });

    for (const group of part.groups) {
      const pause = group.pause_in_clip
        ? 0
        : Math.max(0, Number(part.pause_seconds) || 0);
      const plays = group.repeat_in_clip
        ? 1
        : Math.max(1, Number(part.plays) || 1);
      for (let play = 1; play <= plays; play += 1) {
        for (const name of group.clips || [])
          clip(name, {
            phase: "group",
            part: partIndex,
            group: groupIndex,
            play,
            plays,
          });
        if (adaptive && play === plays) {
          steps.push({
            kind: "answer",
            seconds: ADAPTIVE_SECONDS,
            part: partIndex,
            group: groupIndex,
          });
        } else if (pause > 0) {
          steps.push({
            kind: "pause",
            seconds: pause,
            part: partIndex,
            group: groupIndex,
          });
        }
      }
      if (adaptive)
        steps.push({ kind: "lock", part: partIndex, group: groupIndex });
      groupIndex += 1;
    }
  });

  for (const name of bundle.closing_clips || [])
    clip(name, { phase: "closing", part: null, group: null });
  return steps;
}

export function resumeStep(steps, index) {
  const target = Math.min(Math.max(0, index), steps.length);
  if (target >= steps.length) return target;

  const group = steps[target].group;
  if (group === null || group === undefined) return target;

  let first = target;
  while (first > 0 && steps[first - 1].group === group) first -= 1;
  return first;
}

export function nextClipAfter(steps, index) {
  for (let i = index + 1; i < steps.length; i += 1)
    if (steps[i].kind === "clip") return steps[i].clip;
  return null;
}

export function mark(bundle, answers) {
  const key = bundle.key || {};
  const items = [];
  const parts = bundle.parts.map((part) => {
    let correct = 0;
    let total = 0;
    for (const group of part.groups) {
      for (const item of group.items) {
        const expected = key[String(item.n)] ?? null;
        const given = answers[String(item.n)] ?? null;
        const right = expected !== null && given === expected;
        items.push({ n: item.n, given, expected, correct: right });
        total += 1;
        if (right) correct += 1;
      }
    }
    return { id: part.id, title: part.title, correct, total };
  });
  return {
    raw: items.filter((item) => item.correct).length,
    total: items.length,
    parts,
    items,
  };
}

export function scaled(scale, raw) {
  const table = scale?.table;
  if (!Array.isArray(table) || table.length === 0) return null;

  const row = table
    .filter(([points]) => points <= raw)
    .sort((a, b) => b[0] - a[0])[0];
  const score = row ? row[1] : null;
  const thresholds = scale.thresholds || [];
  const reached = thresholds
    .filter((entry) => score !== null && score >= entry.min)
    .sort((a, b) => b.min - a.min)[0];
  return {
    score,
    max: scale.max ?? null,
    level: reached?.level ?? null,
    leveled: thresholds.length > 0,
  };
}

export function withEdition(bundle, code) {
  const edition = bundle.editions?.[code];
  const own = edition && !edition.base ? edition : null;
  const base = bundle.audio || "";
  const at = (folder, name) => (folder ? `${folder}/${name}` : name);
  const shared = (name) =>
    own?.clips?.[name] ? at(own.audio, own.clips[name]) : at(base, name);
  const local = (names, fallback) =>
    own && names
      ? names.map((name) => at(own.audio, name))
      : (fallback || []).map((name) => at(base, name));

  const copy = structuredClone(bundle);
  copy.edition = own ? code : null;
  copy.opening_clips = local(own?.opening_clips, bundle.opening_clips);
  copy.closing_clips = local(own?.closing_clips, bundle.closing_clips);
  for (const part of copy.parts) {
    const intro = own?.intros?.[String(part.id)];
    if (intro)
      part.intro = {
        ...intro,
        clips: (intro.clips || []).map((name) => at(own.audio, name)),
      };
    else if (part.intro)
      part.intro.clips = (part.intro.clips || []).map((name) => at(base, name));
    for (const group of part.groups) {
      group.clips = (group.clips || []).map(shared);
      if (group.timeline)
        group.timeline = group.timeline.map((entry) => ({
          ...entry,
          clip: shared(entry.clip),
        }));
    }
  }
  return copy;
}

export function secondsLeft(deadline, now = Date.now()) {
  return Math.max(0, Math.ceil((deadline - now) / 1000));
}

export function clock(seconds) {
  const whole = Math.max(0, Math.floor(seconds));
  const minutes = Math.floor(whole / 60);
  return `${minutes}:${String(whole % 60).padStart(2, "0")}`;
}

export function readStore(key, fallback = null) {
  try {
    const raw = localStorage.getItem(key);
    return raw ? JSON.parse(raw) : fallback;
  } catch {
    return fallback;
  }
}

export function writeStore(key, value) {
  try {
    if (value === null || value === undefined) localStorage.removeItem(key);
    else localStorage.setItem(key, JSON.stringify(value));
  } catch {}
}

export function history() {
  const stored = readStore(HISTORY_KEY, {});
  return stored && typeof stored === "object" ? stored : {};
}

export function remember(slug, entry) {
  const all = history();
  all[slug] = [entry, ...(all[slug] || [])].slice(0, HISTORY_LIMIT);
  writeStore(HISTORY_KEY, all);
  return all[slug];
}

export function best(entries) {
  return (entries || []).reduce(
    (top, entry) => (!top || entry.raw > top.raw ? entry : top),
    null,
  );
}

export function keepPending(slug, answers, now = Date.now()) {
  writeStore(PENDING_KEY, { slug, answers, at: now });
}

export function takePending(slug, now = Date.now()) {
  const pending = readStore(PENDING_KEY);
  if (!pending || typeof pending !== "object") return null;

  const fresh =
    typeof pending.at === "number" &&
    pending.at <= now &&
    now - pending.at <= PENDING_TTL_MS;
  if (fresh && pending.slug !== slug) return null;

  writeStore(PENDING_KEY, null);
  const answers = pending.answers;
  if (
    !fresh ||
    !answers ||
    typeof answers !== "object" ||
    Array.isArray(answers)
  )
    return null;
  return answers;
}
