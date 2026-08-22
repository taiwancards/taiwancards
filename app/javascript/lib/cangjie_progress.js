const KEY = "cangjie.progress";
const RUNS = 60;
const TIMES = 8;

function empty() {
  return { lessons: {}, chars: {}, runs: [] };
}

export function load() {
  try {
    return { ...empty(), ...(JSON.parse(localStorage.getItem(KEY)) || {}) };
  } catch {
    return empty();
  }
}

function save(state) {
  try {
    localStorage.setItem(KEY, JSON.stringify(state));
  } catch {}
}

export function recordChar(char, correct, ms = null) {
  const state = load();
  const row = (state.chars[char] ||= { right: 0, wrong: 0, times: [] });
  if (correct) {
    row.right += 1;
    if (ms > 0)
      row.times = [...(row.times || []), Math.round(ms)].slice(-TIMES);
  } else {
    row.wrong += 1;
  }
  save(state);
}

export function recordLesson(slug, right, total) {
  const state = load();
  const row = (state.lessons[slug] ||= { best: 0, total, runs: 0 });
  row.total = total;
  row.runs += 1;
  if (right > row.best) row.best = right;
  save(state);
}

export function recordRun(kind, right, total, ms) {
  const state = load();
  state.runs = [
    ...state.runs,
    { at: Date.now(), kind, right, total, ms: Math.round(ms) },
  ].slice(-RUNS);
  save(state);
}

export function lessonScore(slug) {
  return load().lessons[slug] || null;
}

export function passed(row) {
  return Boolean(row && row.total > 0 && row.best / row.total >= 0.8);
}

export function typedChars(state = load()) {
  return new Set(
    Object.keys(state.chars).filter((char) => state.chars[char].right > 0),
  );
}

function perMinute(runs) {
  const right = runs.reduce((sum, run) => sum + run.right, 0);
  const ms = runs.reduce((sum, run) => sum + run.ms, 0);
  return ms > 0 ? (right * 60000) / ms : 0;
}

export function pace(state = load()) {
  const runs = state.runs.filter(
    (run) => run.kind === "speed" && run.ms > 0 && run.right > 0,
  );
  if (!runs.length) return null;

  return {
    current: perMinute(runs.slice(-5)),
    earlier: runs.length > 5 ? perMinute(runs.slice(0, -5)) : null,
    runs: runs.length,
  };
}
