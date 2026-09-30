const ATTEMPTS = 10;
const PAUSE_MS = 1500;
const BUSY = 429;

export async function postGrade(url, body, headers, onQueued) {
  for (let attempt = 1; ; attempt += 1) {
    const response = await fetch(url, { method: "POST", body, headers });
    if (response.status !== BUSY || attempt >= ATTEMPTS) return response;

    onQueued?.();
    await new Promise((resolve) => setTimeout(resolve, PAUSE_MS));
  }
}
