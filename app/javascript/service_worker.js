const FRAGMENTS = "tc-fragments";
const SHELLS = "tc-shells";
const ASSETS = "tc-assets";
const META = "tc-meta";

const KEPT = [FRAGMENTS, SHELLS, ASSETS, META];

const TITLE_SLOT = "§TITLE§";
const MAIN_SLOT = "§MAIN§";
const CSS_SLOT = "§CSS§";
const JS_SLOT = "§JS§";

const LOCALES = ["en", "ru"];
const WIDTHS = ["narrow", "medium", "wide"];

const BROWSE_RULES = [
  [/^\/(en|ru)\/dict\/?$/, () => "kind:word"],
  [/^\/(en|ru)\/characters\/?$/, () => "kind:character"],
  [/^\/(en|ru)\/sentences\/?$/, () => "kind:sentence"],
  [/^\/(en|ru)\/radicals\/?$/, () => "kind:radical"],
  [/^\/(en|ru)\/liangci\/?$/, () => "kind:measure_word"],
  [/^\/(en|ru)\/zhuci\/?$/, () => "kind:particle"],
  [/^\/(en|ru)\/chengyu\/?$/, () => "pack:chengyu"],
  [/^\/(en|ru)\/search\/?$/, () => "kind:"],
  [
    /^\/(en|ru)\/tocfl\/([A-Za-z0-9]+)$/,
    (match) => `pack:tocfl-${match[2].toLowerCase()}`,
  ],
];

const ROOT = new RegExp(`^/(?:${LOCALES.join("|")})?$`);
const PREFIX = new RegExp(`^/(${LOCALES.join("|")})(?=/|$)`);

const ASSET_PATHS = [
  /^\/assets\//,
  /^\/fonts\//,
  /^\/json\//,
  /^\/icon/,
  /^\/favicon/,
  /^\/apple-touch-icon/,
  /^\/manifest$/,
];

const NEVER = [/^\/auth\//, /^\/(en|ru)\/login$/, /^\/up$/];

const PACKS = /\/packs\//;

self.addEventListener("install", () => self.skipWaiting());

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((names) =>
        Promise.all(
          names
            .filter((name) => !KEPT.includes(name))
            .map((name) => caches.delete(name)),
        ),
      )
      .then(() => self.clients.claim()),
  );
});

self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET") return;

  const url = new URL(request.url);
  if (NEVER.some((rule) => rule.test(url.pathname))) return;

  if (isPage(request, url)) {
    event.respondWith(page(request, url));
    return;
  }

  if (isAsset(url)) event.respondWith(asset(request));
});

function isPage(request, url) {
  if (request.mode === "navigate") return true;
  if (url.origin !== self.location.origin) return false;

  return (request.headers.get("accept") || "").includes("text/html");
}

function isAsset(url) {
  if (PACKS.test(url.pathname)) return false;
  if (url.origin === self.location.origin)
    return ASSET_PATHS.some((rule) => rule.test(url.pathname));

  return /\.(woff2|css|js|json)$/.test(url.pathname);
}

async function asset(request) {
  const cache = await caches.open(ASSETS);
  const hit = await cache.match(request);
  if (hit) return hit;

  const response = await fetch(request);
  if (response.ok || response.type === "opaque")
    cache.put(request, response.clone()).catch(() => {});

  return response;
}

async function page(request, url) {
  if (navigator.onLine === false) {
    const stored = await stale(url);
    if (stored) return stored;
  }

  try {
    return await fetch(request);
  } catch (error) {
    const stored = await stale(url);
    if (stored) return stored;

    throw error;
  }
}

function localeOf(pathname) {
  const found = pathname.split("/")[1];

  return LOCALES.includes(found) ? found : null;
}

function relocate(pathname, locale) {
  const bare = pathname.replace(PREFIX, "");

  return `/${locale}${bare === "/" ? "" : bare}`;
}

async function storedLocale() {
  try {
    const cache = await caches.open(META);
    const hit = await cache.match("/__meta/packs");
    if (!hit) return null;

    const state = await hit.json();
    const pack = state.core || Object.values(state)[0];

    return pack && LOCALES.includes(pack.locale) ? pack.locale : null;
  } catch (error) {
    return null;
  }
}

async function localesFor(pathname) {
  const asked = localeOf(pathname);
  const stored = await storedLocale();

  return [...new Set([asked, stored, ...LOCALES].filter(Boolean))];
}

function normalise(pathname) {
  return pathname.length > 1 ? pathname.replace(/\/+$/, "") : pathname;
}

async function fragmentFor(pathname) {
  const cache = await caches.open(FRAGMENTS);
  const hit = await cache.match(`/__frag${normalise(pathname)}`);

  return hit ? hit.json() : null;
}

async function stale(url) {
  const path = normalise(url.pathname);
  const locales = await localesFor(path);
  const entry = ROOT.test(path);

  for (const locale of locales) {
    const target = relocate(path, locale);
    const found = entry
      ? await fragmentFor(`/${locale}/offline/browse`)
      : await fragmentFor(target);
    if (found) return render(locale, found, "");

    const rule = BROWSE_RULES.find(([pattern]) => pattern.test(target));
    if (!rule) continue;

    const browse = await fragmentFor(`/${locale}/offline/browse`);
    if (browse) return render(locale, browse, rule[1](target.match(rule[0])));
  }

  for (const locale of locales) {
    const home = await fragmentFor(`/${locale}/offline`);
    if (home) return render(locale, home, entry ? "" : "absent:1");
  }

  return null;
}

async function shellFor(locale, width) {
  const cache = await caches.open(SHELLS);

  for (const wanted of [width, ...WIDTHS]) {
    for (const language of [locale, ...LOCALES]) {
      const hit = await cache.match(`/__shell/${language}/${wanted}`);
      if (hit) return hit.text();
    }
  }

  return null;
}

async function assetTags() {
  const cache = await caches.open(META);
  const hit = await cache.match("/__meta/assets");

  return hit ? hit.json() : { css: "", js: "" };
}

async function render(locale, fragment, preset) {
  const shell = await shellFor(locale, fragment.w);
  if (!shell) return null;

  const tags = await assetTags();

  const html = shell
    .replace(CSS_SLOT, () => tags.css || "")
    .replace(JS_SLOT, () => tags.js || "")
    .replace(TITLE_SLOT, () => escapeText(fragment.t || ""))
    .replace(MAIN_SLOT, () => fragment.m || "")
    .replace(/<html\b/, () => `<html data-offline="${preset}"`);

  return new Response(html, {
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

function escapeText(text) {
  return text.replace(
    /[&<>]/g,
    (character) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" })[character],
  );
}
