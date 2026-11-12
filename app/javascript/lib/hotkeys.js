const FIELDS = "input, textarea, select, [contenteditable]";
const ACTIVATABLE = "button, a[href], summary, input, select, textarea";

export function typingElsewhere(event) {
  if (event.metaKey || event.ctrlKey || event.altKey) return true;
  return Boolean(event.target?.closest?.(FIELDS));
}

export function activatesFocus(event) {
  return Boolean(event.target?.closest?.(ACTIVATABLE));
}
