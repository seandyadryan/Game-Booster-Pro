const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('sharp');

async function main() {
  const root = path.resolve(__dirname, '..');
  const store = path.join(root, 'play_store');
  const featureInput = process.argv[2];
  if (featureInput) {
    await sharp(featureInput)
      .resize(1024, 500, {fit: 'contain', background: '#070e13'})
      .png()
      .toFile(path.join(store, 'feature-graphic.png'));
  }
  const counts = {};
  for (const [name, max] of [['short-description', 80], ['full-description', 4000]]) {
    const text = (await fs.readFile(path.join(store, name + '.txt'), 'utf8')).trimEnd();
    const characters = Array.from(text).length;
    if (characters > max) throw new Error(`${name}: ${characters} exceeds ${max}`);
    counts[name] = {characters, maximum: max};
  }
  const images = [];
  for (const group of ['phone', 'desktop']) {
    const names = (await fs.readdir(path.join(store, group))).filter(name => name.endsWith('.png')).sort();
    const minimum = group === 'phone' ? 2 : 4;
    if (names.length < minimum || names.length > 8) throw new Error(`Invalid ${group} screenshot count`);
    for (const name of names) {
      const file = path.join(store, group, name);
      const metadata = await sharp(file).metadata();
      const {size: bytes} = await fs.stat(file);
      const {width, height} = metadata;
      const minEdge = group === 'phone' ? 320 : 1080;
      const maxEdge = group === 'phone' ? 3840 : 7680;
      if (Math.min(width, height) < minEdge || Math.max(width, height) > maxEdge) throw new Error(`Invalid dimensions: ${name}`);
      if (width * 9 !== height * 16 && width * 16 !== height * 9) throw new Error(`Invalid aspect ratio: ${name}`);
      if (bytes > 8 * 1024 * 1024) throw new Error(`Oversized image: ${name}`);
      images.push({file: `${group}/${name}`, width, height, bytes});
    }
  }
  const featureFile = path.join(store, 'feature-graphic.png');
  const feature = await sharp(featureFile).metadata();
  const featureBytes = (await fs.stat(featureFile)).size;
  if (feature.width !== 1024 || feature.height !== 500 || featureBytes > 15 * 1024 * 1024) throw new Error('Invalid feature graphic');
  images.unshift({file: 'feature-graphic.png', width: 1024, height: 500, bytes: featureBytes});
  const report = {descriptions: counts, images};
  await fs.writeFile(path.join(store, 'asset-validation.json'), JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify(report, null, 2));
}

main().catch(error => {console.error(error.message); process.exitCode = 1;});
