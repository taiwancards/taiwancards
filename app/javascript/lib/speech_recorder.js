const MIC_SETTLE_MS = 150

export async function toWav(blob) {
  const ctx = new (window.AudioContext || window.webkitAudioContext)()
  try {
    return encodeWav(await ctx.decodeAudioData(await blob.arrayBuffer()))
  } finally {
    ctx.close()
  }
}

export function encodeWav(audioBuffer) {
  const sr = audioBuffer.sampleRate
  const samples = audioBuffer.getChannelData(0)
  const out = new ArrayBuffer(44 + samples.length * 2)
  const view = new DataView(out)
  const str = (off, s) => {
    for (let i = 0; i < s.length; i++) view.setUint8(off + i, s.charCodeAt(i))
  }
  str(0, "RIFF")
  view.setUint32(4, 36 + samples.length * 2, true)
  str(8, "WAVE")
  str(12, "fmt ")
  view.setUint32(16, 16, true)
  view.setUint16(20, 1, true)
  view.setUint16(22, 1, true)
  view.setUint32(24, sr, true)
  view.setUint32(28, sr * 2, true)
  view.setUint16(32, 2, true)
  view.setUint16(34, 16, true)
  str(36, "data")
  view.setUint32(40, samples.length * 2, true)
  let off = 44
  for (let i = 0; i < samples.length; i++) {
    const s = Math.max(-1, Math.min(1, samples[i]))
    view.setInt16(off, s < 0 ? s * 0x8000 : s * 0x7fff, true)
    off += 2
  }
  return new Blob([out], { type: "audio/wav" })
}

export class SpeechRecorder {
  async start() {
    if (this.recording) return true

    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    } catch (error) {
      this.error = error
      return false
    }

    this.chunks = []
    await new Promise((resolve) => setTimeout(resolve, MIC_SETTLE_MS))
    if (!this.stream) return false

    this.recorder = new MediaRecorder(this.stream)
    this.recorder.ondataavailable = (event) => event.data.size && this.chunks.push(event.data)
    this.recorder.start()
    this.recording = true
    return true
  }

  stop() {
    if (!this.recording) return Promise.resolve(null)

    this.recording = false
    return new Promise((resolve) => {
      this.recorder.onstop = async () => {
        this.release()
        try {
          resolve(await toWav(new Blob(this.chunks, { type: this.recorder.mimeType || "audio/webm" })))
        } catch {
          resolve(null)
        }
      }
      this.recorder.stop()
    })
  }

  release() {
    this.stream?.getTracks().forEach((track) => track.stop())
    this.stream = null
  }
}
