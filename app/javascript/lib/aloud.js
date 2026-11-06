const PARTS = ".aloud-gate, .aloud-options";

export function revealOptions(scope) {
  scope.querySelectorAll(PARTS).forEach((part) => {
    part.dataset.revealed = "";
  });
  return scope.querySelector(".aloud-options button:not(:disabled)");
}
