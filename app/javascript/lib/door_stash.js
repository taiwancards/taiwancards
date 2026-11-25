export const STASH_KEY = "doors.pending";
export const STASH_TTL_MS = 2 * 60 * 60 * 1000;
export const HAN = /\p{Script=Han}/u;

function storage() {
  try {
    return window.localStorage;
  } catch {
    return null;
  }
}

function read(key) {
  try {
    const raw = storage()?.getItem(key);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

function write(key, value) {
  try {
    const store = storage();
    if (!store) return false;
    if (value === null) store.removeItem(key);
    else store.setItem(key, JSON.stringify(value));
    return true;
  } catch {
    return false;
  }
}

export function problem(text, limit) {
  const body = String(text || "").trim();
  if (!body) return "empty";
  if (body.length > limit) return "too_long";
  if (!HAN.test(body)) return "no_hanzi";
  return null;
}

function fresh(entry, now) {
  return (
    Boolean(entry) &&
    typeof entry === "object" &&
    typeof entry.at === "number" &&
    entry.at <= now &&
    now - entry.at <= STASH_TTL_MS
  );
}

function usable(entry, door, limit, now) {
  if (!fresh(entry, now) || entry.door !== door) return false;
  return typeof entry.text === "string" && problem(entry.text, limit) === null;
}

export function keep(door, text, name, limit, now = Date.now()) {
  if (problem(text, limit)) return false;
  return write(STASH_KEY, {
    door,
    text: String(text).trim(),
    name: String(name || "").trim(),
    at: now,
  });
}

export function peek(door, limit, now = Date.now()) {
  const entry = read(STASH_KEY);
  return usable(entry, door, limit, now) ? entry : null;
}

export function take(door, limit, now = Date.now()) {
  const entry = read(STASH_KEY);
  if (entry === null) return null;
  if (fresh(entry, now) && entry.door !== door) return null;

  write(STASH_KEY, null);
  if (!usable(entry, door, limit, now)) return null;
  return {
    text: entry.text,
    name: typeof entry.name === "string" ? entry.name : "",
  };
}

export function sweep(now = Date.now()) {
  const entry = read(STASH_KEY);
  if (entry !== null && !fresh(entry, now)) write(STASH_KEY, null);
}
