const STOP_GRACE_MS = 150

export function playClip(url, stopMs = 0) {
  const sound = new Audio(url)
  let timer = null

  const halt = () => {
    if (timer) clearTimeout(timer)
    timer = null
    sound.pause()
  }

  if (stopMs > 0) {
    const limit = stopMs / 1000
    sound.addEventListener("timeupdate", () => {
      if (sound.currentTime >= limit) halt()
    })
    sound.addEventListener("playing", () => {
      timer = setTimeout(halt, stopMs + STOP_GRACE_MS)
    }, { once: true })
  }

  sound.play().catch(() => {})
  return { stop: halt }
}
