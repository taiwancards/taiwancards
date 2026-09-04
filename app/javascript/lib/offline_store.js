export const FRAGMENTS = "tc-fragments";
export const SHELLS = "tc-shells";
export const ASSETS = "tc-assets";
export const META = "tc-meta";

export const STATE = "/__meta/packs";

export const supported = () => typeof caches !== "undefined";

export function json(payload) {
  return new Response(JSON.stringify(payload), {
    headers: { "content-type": "application/json" },
  });
}

export async function readJson(cacheName, key) {
  if (!supported()) return null;

  const cache = await caches.open(cacheName);
  const hit = await cache.match(key);

  return hit ? hit.json() : null;
}

export async function writeJson(cacheName, key, payload) {
  const cache = await caches.open(cacheName);
  await cache.put(key, json(payload));
}

export async function installed() {
  return (await readJson(META, STATE)) || {};
}

export async function saveInstalled(state) {
  await writeJson(META, STATE, state);
}

export async function indexFor(id) {
  return readJson(META, `/__index/${id}`);
}

export function humanBytes(bytes, unit = "MB") {
  const mb = bytes / 1048576;

  return `${mb >= 10 ? Math.round(mb) : mb.toFixed(1)} ${unit}`;
}
