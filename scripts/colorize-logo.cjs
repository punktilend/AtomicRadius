/**
 * Colorizes AtomicRadius.png:
 *
 * ar-logo-dark.png  — #0D1F0D background, #39D353 line art (for dark panels)
 * ar-logo-light.png — transparent/white bg, #39D353 line art (for general use)
 * ar-logo-mono.png  — transparent bg, #0D1F0D line art (for light backgrounds)
 */

const { Jimp } = require('jimp');

const INPUT       = 'C:/Users/adamm/Downloads/AtomicRadius.png';
const OUT_DARK    = 'C:/Users/adamm/AtomicRadius/fluxer_app/src/images/ar-logo-dark.png';
const OUT_LIGHT   = 'C:/Users/adamm/AtomicRadius/fluxer_app/src/images/ar-logo-light.png';
const OUT_MONO    = 'C:/Users/adamm/AtomicRadius/fluxer_app/src/images/ar-logo-mono.png';

// Also copy to Downloads so user can easily find them
const DL_DARK  = 'C:/Users/adamm/Downloads/AtomicRadius-dark.png';
const DL_LIGHT = 'C:/Users/adamm/Downloads/AtomicRadius-light.png';

async function makeDarkVersion(inputPath, outputPath) {
  const img = await Jimp.read(inputPath);

  img.scan(0, 0, img.bitmap.width, img.bitmap.height, function (x, y, idx) {
    const r = this.bitmap.data[idx];
    const g = this.bitmap.data[idx + 1];
    const b = this.bitmap.data[idx + 2];
    const a = this.bitmap.data[idx + 3];

    // Perceived luminance of the drawn pixel
    const lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255;

    if (a < 30 || lum > 0.85) {
      // Background: transparent or near-white → solid dark green
      this.bitmap.data[idx]     = 0x0D;
      this.bitmap.data[idx + 1] = 0x1F;
      this.bitmap.data[idx + 2] = 0x0D;
      this.bitmap.data[idx + 3] = 255;
    } else {
      // Line art: remap toward brand green, keep it opaque
      // lum=0 (black line) → full #39D353; lum=0.5 (gray) → lighter green
      const t = 1 - lum;  // 1 = darkest line, 0 = lightest
      this.bitmap.data[idx]     = Math.round(0x0D + (0x39 - 0x0D) * t);
      this.bitmap.data[idx + 1] = Math.round(0x1F + (0xD3 - 0x1F) * t);
      this.bitmap.data[idx + 2] = Math.round(0x0D + (0x53 - 0x0D) * t);
      this.bitmap.data[idx + 3] = 255;
    }
  });

  await img.write(outputPath);
  console.log('Written:', outputPath);
}

async function makeLightVersion(inputPath, outputPath, lineR, lineG, lineB) {
  const img = await Jimp.read(inputPath);

  img.scan(0, 0, img.bitmap.width, img.bitmap.height, function (x, y, idx) {
    const r = this.bitmap.data[idx];
    const g = this.bitmap.data[idx + 1];
    const b = this.bitmap.data[idx + 2];
    const a = this.bitmap.data[idx + 3];

    const lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255;

    if (a < 30 || lum > 0.85) {
      // Background: keep transparent
      this.bitmap.data[idx]     = 255;
      this.bitmap.data[idx + 1] = 255;
      this.bitmap.data[idx + 2] = 255;
      this.bitmap.data[idx + 3] = 0;
    } else {
      // Line art: recolor with chosen fg, preserve darkness as opacity
      const t = 1 - lum;
      this.bitmap.data[idx]     = lineR;
      this.bitmap.data[idx + 1] = lineG;
      this.bitmap.data[idx + 2] = lineB;
      this.bitmap.data[idx + 3] = Math.round(255 * t);
    }
  });

  await img.write(outputPath);
  console.log('Written:', outputPath);
}

async function main() {
  // Dark: solid #0D1F0D bg + #39D353 lines
  await makeDarkVersion(INPUT, OUT_DARK);
  await makeDarkVersion(INPUT, DL_DARK);

  // Light: transparent bg + #39D353 green lines (for use on any bg)
  await makeLightVersion(INPUT, OUT_LIGHT, 0x39, 0xD3, 0x53);
  await makeLightVersion(INPUT, DL_LIGHT, 0x39, 0xD3, 0x53);

  // Mono: transparent bg + #0D1F0D dark lines (for light backgrounds)
  await makeLightVersion(INPUT, OUT_MONO, 0x0D, 0x1F, 0x0D);

  console.log('\nAll done! Files saved to:');
  console.log('  App:', OUT_DARK);
  console.log('  App:', OUT_LIGHT);
  console.log('  App:', OUT_MONO);
  console.log('  Downloads:', DL_DARK);
  console.log('  Downloads:', DL_LIGHT);
}

main().catch(console.error);
