const KEY = "audio.rate";

export const RATES = [1, 0.75, 0.5];

export function audioRate() {
  try {
    const rate = Number(localStorage.getItem(KEY));
    return RATES.includes(rate) ? rate : 1;
  } catch {
    return 1;
  }
}

export function setAudioRate(rate) {
  try {
    if (rate === 1) localStorage.removeItem(KEY);
    else localStorage.setItem(KEY, String(rate));
  } catch {}
}

export function applyAudioRate(sound) {
  const rate = audioRate();
  sound.defaultPlaybackRate = rate;
  sound.playbackRate = rate;
  sound.preservesPitch = true;
  return rate;
}
