export function writerSize(container, count = 1, { min = 130, max = 260, gap = 12 } = {}) {
  const width = container?.clientWidth || 0
  if (!width) return min

  const perRow = Math.max(1, Math.min(count, Math.floor((width + gap) / (min + gap))))
  const side = Math.floor((width - (perRow - 1) * gap) / perRow)
  return Math.max(min, Math.min(max, side))
}
