const FIELDS = "input, textarea, select, [contenteditable]";
const ACTIVATABLE = "button, a[href], summary, input, select, textarea";

export function typingElsewhere(event) {
  if (event.metaKey || event.ctrlKey || event.altKey) return true;
  return Boolean(event.target?.closest?.(FIELDS));
}

export function activatesFocus(event) {
  return Boolean(event.target?.closest?.(ACTIVATABLE));
}

const POSITIONS = {
  Digit1: "1",
  Digit2: "2",
  Digit3: "3",
  Digit4: "4",
  Digit5: "5",
  Digit6: "6",
  Digit7: "7",
  Digit8: "8",
  Digit9: "9",
  Digit0: "0",
  Minus: "-",
  Semicolon: ";",
  Comma: ",",
  Period: ".",
  Slash: "/",
  KeyQ: "q",
  KeyW: "w",
  KeyE: "e",
  KeyR: "r",
  KeyT: "t",
  KeyY: "y",
  KeyU: "u",
  KeyI: "i",
  KeyO: "o",
  KeyP: "p",
  KeyA: "a",
  KeyS: "s",
  KeyD: "d",
  KeyF: "f",
  KeyG: "g",
  KeyH: "h",
  KeyJ: "j",
  KeyK: "k",
  KeyL: "l",
  KeyZ: "z",
  KeyX: "x",
  KeyC: "c",
  KeyV: "v",
  KeyB: "b",
  KeyN: "n",
  KeyM: "m",
};

export function positionKey(event) {
  return POSITIONS[event.code] ?? event.key;
}
