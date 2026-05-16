/**
 * Generate portal + admin favicons from many_faces_mobile/assets/logo-raster-source.png.
 *
 * Uses sharp (and to-ico) resolved from many_faces_mobile devDependencies.
 *
 * Run from repo root:
 *   node ./scripts/generate-brand-favicons.mjs
 *
 * Or from a submodule:
 *   yarn favicon:generate
 */
import { createRequire } from 'node:module';
import { existsSync } from 'node:fs';
import { writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.join(__dirname, '..');
const mobilePkg = path.join(repoRoot, 'many_faces_mobile/package.json');

if (!existsSync(mobilePkg)) {
  console.error('many_faces_mobile not found; run from many_faces_main root.');
  process.exit(1);
}

const require = createRequire(mobilePkg);
const sharp = require('sharp');
const toIco = require('to-ico');

const SOURCE = path.join(repoRoot, 'many_faces_mobile/assets/logo-raster-source.png');
const SAFE_RATIO = 0.72;
const BG = '#ffffff';

const TARGETS = [
  { name: 'many_faces_portal', publicDir: path.join(repoRoot, 'many_faces_portal/public') },
  { name: 'many_faces_admin', publicDir: path.join(repoRoot, 'many_faces_admin/public') },
];

async function buildPaddedSquare(size) {
  const inner = Math.round(size * SAFE_RATIO);
  const resized = await sharp(SOURCE)
    .ensureAlpha()
    .resize(inner, inner, { fit: 'contain', position: 'center' })
    .png()
    .toBuffer();

  return sharp({
    create: { width: size, height: size, channels: 4, background: BG },
  })
    .composite([{ input: resized, gravity: 'center' }])
    .png()
    .toBuffer();
}

async function writeFaviconSet(publicDir) {
  const apple = await buildPaddedSquare(180);
  const png48 = await buildPaddedSquare(48);
  const png32 = await buildPaddedSquare(32);
  const png16 = await buildPaddedSquare(16);

  const ico = await toIco([png16, png32, png48]);

  await writeFile(path.join(publicDir, 'apple-touch-icon.png'), apple);
  await writeFile(path.join(publicDir, 'favicon-32x32.png'), png32);
  await writeFile(path.join(publicDir, 'favicon-16x16.png'), png16);
  await writeFile(path.join(publicDir, 'favicon.ico'), ico);
}

async function main() {
  if (!existsSync(SOURCE)) {
    console.error(`Missing canonical source: ${SOURCE}`);
    console.error('Run: cd many_faces_mobile && yarn icons:export');
    process.exit(1);
  }

  for (const { name, publicDir } of TARGETS) {
    if (!existsSync(publicDir)) {
      console.error(`Missing public dir for ${name}: ${publicDir}`);
      process.exit(1);
    }
    await writeFaviconSet(publicDir);
    console.log(`Wrote favicons → ${publicDir}`);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
