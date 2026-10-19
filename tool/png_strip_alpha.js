// Re-saves RGBA PNGs as 24-bit RGB PNGs (no alpha), flattened onto white.
// Google Play requires the feature graphic and screenshots without alpha.
//
//   node tool/png_strip_alpha.js <file.png> [more.png ...]
//
// Pure Node (zlib only), because the store-asset generator renders RGBA and
// this machine has no image tooling. Handles 8-bit RGBA, non-interlaced — what
// Flutter's toImage/PNG encoder produces.
const fs = require('fs');
const zlib = require('zlib');

const SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();

function crc32(buf) {
  let c = 0xffffffff;
  for (const b of buf) c = CRC_TABLE[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}

function paeth(a, b, c) {
  const p = a + b - c;
  const pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
  return pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
}

function strip(path) {
  const png = fs.readFileSync(path);
  if (!png.subarray(0, 8).equals(SIGNATURE)) throw new Error(`${path}: not a PNG`);

  let off = 8, width, height, bitDepth, colorType, interlace;
  const idat = [];
  while (off < png.length) {
    const len = png.readUInt32BE(off);
    const type = png.toString('ascii', off + 4, off + 8);
    const data = png.subarray(off + 8, off + 8 + len);
    if (type === 'IHDR') {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      bitDepth = data[8];
      colorType = data[9];
      interlace = data[12];
    } else if (type === 'IDAT') {
      idat.push(data);
    }
    off += 12 + len;
  }

  if (colorType === 2) return console.log(`${path}: already RGB`);
  if (colorType !== 6 || bitDepth !== 8 || interlace !== 0) {
    throw new Error(`${path}: unsupported PNG (type ${colorType}, depth ${bitDepth})`);
  }

  const raw = zlib.inflateSync(Buffer.concat(idat));
  const bpp = 4, stride = width * bpp;
  const pixels = Buffer.alloc(height * stride);
  for (let y = 0; y < height; y++) {
    const filter = raw[y * (stride + 1)];
    const src = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    const row = pixels.subarray(y * stride, (y + 1) * stride);
    const prev = y > 0 ? pixels.subarray((y - 1) * stride, y * stride) : null;
    for (let x = 0; x < stride; x++) {
      const a = x >= bpp ? row[x - bpp] : 0;
      const b = prev ? prev[x] : 0;
      const c = prev && x >= bpp ? prev[x - bpp] : 0;
      let v = src[x];
      if (filter === 1) v += a;
      else if (filter === 2) v += b;
      else if (filter === 3) v += (a + b) >> 1;
      else if (filter === 4) v += paeth(a, b, c);
      row[x] = v & 0xff;
    }
  }

  // RGB, flattened onto white wherever anything was transparent.
  const out = Buffer.alloc(height * (width * 3 + 1));
  for (let y = 0; y < height; y++) {
    out[y * (width * 3 + 1)] = 0;
    for (let x = 0; x < width; x++) {
      const s = y * stride + x * 4;
      const d = y * (width * 3 + 1) + 1 + x * 3;
      const alpha = pixels[s + 3] / 255;
      for (let ch = 0; ch < 3; ch++) {
        out[d + ch] = Math.round(pixels[s + ch] * alpha + 255 * (1 - alpha));
      }
    }
  }

  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;
  ihdr[9] = 2; // truecolour, no alpha
  fs.writeFileSync(
    path,
    Buffer.concat([
      SIGNATURE,
      chunk('IHDR', ihdr),
      chunk('IDAT', zlib.deflateSync(out, { level: 9 })),
      chunk('IEND', Buffer.alloc(0)),
    ]),
  );
  console.log(`${path}: ${width}x${height} → 24-bit RGB`);
}

for (const f of process.argv.slice(2)) strip(f);
