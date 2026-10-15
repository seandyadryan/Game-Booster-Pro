const fs = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require('sharp');

const codePoints = text => Array.from(text).length;
const shotNames = ['01-dashboard.png', '02-tools.png', '03-display-game-tools.png', '04-network-latency.png'];

async function main() {
  const root = path.resolve(__dirname, '..');
  const store = path.join(root, 'play_store');
  const latest = path.join(store, 'latest');
  const source = JSON.parse(await fs.readFile(path.join(store, 'listing-source.json'), 'utf8'));
  if (Object.keys(source).length !== 29) throw new Error('Expected English plus the 28 requested locales.');
  const contact = '\n\nPT Deploy Dulu Pulang Nanti\nSupport: seandyadryan2@gmail.com';
  const report = {appPackage: 'com.deploydulupulangnanti.gameboosterpro', appInterfaceLanguage: 'en', consoleApplied: false, locales: {}, assets: []};
  const combined = ['# Current Localized Store Text', '', 'Interface and shared images: English. Titles and descriptions: localized below.', ''];
  for (const [locale, entry] of Object.entries(source)) {
    const full = entry.full.trim() + contact;
    const counts = {title: codePoints(entry.title), short: codePoints(entry.short), full: codePoints(full)};
    if (counts.title > 30 || counts.short > 80 || counts.full > 4000) {
      throw new Error(locale + ' exceeds field limits: ' + JSON.stringify(counts));
    }
    if (/boost|fps|AI Network|GFX Tools/i.test(entry.title + '\n' + entry.short)) {
      throw new Error('Unsupported promotional label in ' + locale);
    }
    const dir = path.join(latest, 'metadata', locale);
    await fs.mkdir(dir, {recursive: true});
    await fs.writeFile(path.join(dir, 'title.txt'), entry.title + '\n');
    await fs.writeFile(path.join(dir, 'short_description.txt'), entry.short + '\n');
    await fs.writeFile(path.join(dir, 'full_description.txt'), full + '\n');
    report.locales[locale] = {characters: counts, metadataDirectory: 'metadata/' + locale, sharedAssets: 'assets', interfaceLanguage: 'en'};
    combined.push('~~~text', '<' + locale + '>', 'Title: ' + entry.title, '', 'Short description: ' + entry.short, '', 'Full description:', full, '</' + locale + '>', '~~~', '');
  }
  for (const [file, content] of [
    ['title.txt', source['en-US'].title],
    ['short-description.txt', source['en-US'].short],
    ['full-description.txt', source['en-US'].full.trim() + contact],
  ]) await fs.writeFile(path.join(store, file), content + '\n');
  await fs.writeFile(path.join(latest, 'ALL_LANGUAGES.md'), combined.join('\n'));

  const assets = [
    {file: 'feature-graphic.png', width: 1024, height: 500, maxBytes: 15 * 1024 * 1024},
    {file: 'app-icon.png', width: 512, height: 512, maxBytes: 1024 * 1024},
    ...['phone', 'desktop'].flatMap(group => shotNames.map(name => ({
      file: group + '/' + name,
      width: group === 'phone' ? 1080 : 1920,
      height: group === 'phone' ? 1920 : 1080,
      maxBytes: 8 * 1024 * 1024,
    }))),
  ];
  for (const asset of assets) {
    const src = path.join(store, asset.file);
    const bytes = await fs.readFile(src);
    const info = await sharp(bytes).metadata();
    if (info.width !== asset.width || info.height !== asset.height || bytes.length > asset.maxBytes) {
      throw new Error('Invalid upload asset: ' + asset.file);
    }
    const dest = path.join(latest, 'assets', asset.file);
    await fs.mkdir(path.dirname(dest), {recursive: true});
    await fs.writeFile(dest, bytes);
    report.assets.push({file: 'assets/' + asset.file, width: info.width, height: info.height, bytes: bytes.length, sha256: crypto.createHash('sha256').update(bytes).digest('hex')});
  }
  await fs.mkdir(path.join(latest, 'privacy'), {recursive: true});
  await fs.copyFile(path.join(root, 'docs', 'index.html'), path.join(latest, 'privacy', 'index.html'));
  await fs.writeFile(path.join(latest, 'asset-validation.json'), JSON.stringify(report, null, 2) + '\n');
  await fs.mkdir(path.join(latest, 'custom-store-listings'), {recursive: true});
  await fs.writeFile(path.join(latest, 'custom-store-listings', 'apply-to-existing-listings.json'), JSON.stringify({
    status: 'prepared_locally_not_applied_to_play_console',
    existingCustomListingIds: [],
    inventoryStatus: 'No Play Console export or authenticated inventory was supplied.',
    action: 'For each existing custom store listing, replace every supported locale with the matching metadata folder and replace the icon, feature graphic and screenshots with the shared assets. Remove superseded claims and media. Preserve the existing targeting unless intentionally changing it.',
    localeMapping: report.locales,
    screenshotLanguage: 'en',
  }, null, 2) + '\n');
  console.log('Prepared ' + Object.keys(source).length + ' locales and ' + report.assets.length + ' validated images.');
}

main().catch(error => {console.error(error.message); process.exitCode = 1;});
