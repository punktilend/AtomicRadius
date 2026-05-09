/**
 * Colorizes AtomicRadius.png using Jimp (pure JS, no native deps):
 *   Dark version:  dark green bg (#0D1F0D) + bright green lines (#39D353)
 *   Light version: white bg (#FFFFFF) + dark green lines (#0D1F0D)
 */

import Jimp from 'jimp';
import path from 'path';

const INPUT        = 'C:/Users/adamm/Downloads/AtomicRadius.png';
const OUTPUT_DARK  = 'C:/Users/adamm/AtomicRadius/fluxer_app/src/images/ar-logo-dark.png';
const OUTPUT_LIGHT = 'C:/Users/adamm/AtomicRadius/fluxer_app/src/images/ar-logo-light.png';

async function colorize(inputPath, outputPath, bgR, bgG, bgB, fgR, fgG, fgB) {
  const img = await Jimp.read(inputPath);

  img.scan(0, 0, img.bitmap.width, img.bitmap.height, function (x, y, idx) {
    const r = this.bitmap.data[idx];
    const g = this.bitmap.data[idx + 1];
    const b = this.bitmap.data[idx + 2];

    // Perceived luminance: 1.0 = white (background), 0.0 = black (lines)
    const lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255;

    // Lerp: lum=1 → bg color, lum=0 → fg color
    this.bitmap.data[idx]     = Math.round(fgR + (bgR - fgR) * lum);
    this.bitmap.data[idx + 1] = Math.round(fgG + (bgG - fgG) * lum);
    this.bitmap.data[idx + 2] = Math.round(fgB + (bgB - fgB) * lum);
    // keep alpha as-is
  });

  await img.writeAsync(outputPath);
  console.log('Written:', outputPath);
}

// Dark version: dark green bg + bright green line art
await colorize(INPUT, OUTPUT_DARK,
  0x0D, 0x1F, 0x0D,   // bg = #0D1F0D
  0x39, 0xD3, 0x53    // fg = #39D353
);

// Light version: white bg + dark green line art
await colorize(INPUT, OUTPUT_LIGHT,
  0xFF, 0xFF, 0xFF,   // bg = #FFFFFF
  0x0D, 0x1F, 0x0D    // fg = #0D1F0D
);

console.log('Done!');
