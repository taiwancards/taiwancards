const QUALITIES = [0.85, 0.72, 0.6];
const OVERLAP_MIN = 160;
const OVERLAP_SHARE = 0.03;

async function decode(file) {
  if ("createImageBitmap" in window) {
    try {
      return await createImageBitmap(file, { imageOrientation: "from-image" });
    } catch (_) {}
  }

  const url = URL.createObjectURL(file);
  try {
    const image = new Image();
    image.decoding = "async";
    image.src = url;
    await image.decode();
    return image;
  } finally {
    URL.revokeObjectURL(url);
  }
}

function size(source) {
  return [
    source.naturalWidth || source.width,
    source.naturalHeight || source.height,
  ];
}

function encode(canvas, quality) {
  return new Promise((resolve) =>
    canvas.toBlob(resolve, "image/jpeg", quality),
  );
}

export function partsPlan(width, height, { tallRatio, maxParts }) {
  if (maxParts < 2 || height <= width * tallRatio) return [[0, height]];

  const count = Math.min(maxParts, Math.ceil(height / (width * tallRatio)));
  const overlap = Math.max(OVERLAP_MIN, Math.round(height * OVERLAP_SHARE));
  const part = Math.ceil((height + (count - 1) * overlap) / count);
  return Array.from({ length: count }, (_, index) => {
    const top = index * (part - overlap);
    return [top, Math.min(part, height - top)];
  });
}

async function render(source, width, top, height, { edge, maxBytes }) {
  const scale = Math.min(1, edge / Math.max(width, height));
  const canvas = document.createElement("canvas");
  canvas.width = Math.max(1, Math.round(width * scale));
  canvas.height = Math.max(1, Math.round(height * scale));
  const context = canvas.getContext("2d");
  context.fillStyle = "#fff";
  context.fillRect(0, 0, canvas.width, canvas.height);
  context.imageSmoothingQuality = "high";
  context.drawImage(
    source,
    0,
    top,
    width,
    height,
    0,
    0,
    canvas.width,
    canvas.height,
  );

  for (const quality of QUALITIES) {
    const blob = await encode(canvas, quality);
    if (blob && blob.size <= maxBytes) return blob;
  }

  throw new Error("too_large");
}

export async function shrinkImage(file, options) {
  const source = await decode(file);
  try {
    const [width, height] = size(source);
    if (!width || !height) throw new Error("not_image");
    if (Math.min(width, height) < options.minEdge) throw new Error("too_small");

    const blobs = [];
    for (const [top, partHeight] of partsPlan(width, height, options)) {
      blobs.push(await render(source, width, top, partHeight, options));
    }
    return blobs;
  } finally {
    if (source.close) source.close();
  }
}
