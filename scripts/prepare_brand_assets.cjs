const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('sharp');

async function main() {
  const root = path.resolve(__dirname, '..');
  const [featurePath, iconPath] = process.argv.slice(2);
  if (!featurePath || !iconPath) throw new Error('Provide the generated feature graphic and icon paths.');
  const feature = await fs.readFile(featurePath);
  const icon = await fs.readFile(iconPath);
  await sharp(feature).resize(1024, 500, {fit: 'contain', background: '#0b1518'}).removeAlpha().png().toFile(path.join(root, 'play_store', 'feature-graphic.png'));
  await sharp(icon).resize(1024, 1024).removeAlpha().png().toFile(path.join(root, 'assets', 'app_icon.png'));
  await sharp(icon).resize(512, 512).removeAlpha().png().toFile(path.join(root, 'play_store', 'app-icon.png'));
  const groups = [
    'android/app/src/main/res/mipmap-mdpi',
    'android/app/src/main/res/mipmap-hdpi',
    'android/app/src/main/res/mipmap-xhdpi',
    'android/app/src/main/res/mipmap-xxhdpi',
    'android/app/src/main/res/mipmap-xxxhdpi',
    'ios/Runner/Assets.xcassets/AppIcon.appiconset',
    'macos/Runner/Assets.xcassets/AppIcon.appiconset',
    'web/icons',
  ];
  for (const group of groups) {
    for (const name of await fs.readdir(path.join(root, group))) {
      if (!name.endsWith('.png')) continue;
      const target = path.join(root, group, name);
      const {width, height} = await sharp(target).metadata();
      await sharp(icon).resize(width, height).removeAlpha().png().toFile(target);
    }
  }
  const favicon = path.join(root, 'web', 'favicon.png');
  const dimensions = await sharp(favicon).metadata();
  await sharp(icon).resize(dimensions.width, dimensions.height).removeAlpha().png().toFile(favicon);
  console.log('Updated feature graphic, store icon, launcher PNGs and favicon.');
}

main().catch(error => {console.error(error.message); process.exitCode = 1;});
