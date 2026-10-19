const fs = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');

const sha256 = bytes => crypto.createHash('sha256').update(bytes).digest('hex');

async function runtimeFingerprint(root) {
  const files = [
    'pubspec.lock', 'assets/app_icon.png', 'assets/flying_rocket.png',
    'assets/privacy-policy.txt', 'android/app/src/main/AndroidManifest.xml',
  ];
  async function walk(relative) {
    for (const entry of await fs.readdir(path.join(root, relative), {withFileTypes: true})) {
      const name = relative + '/' + entry.name;
      if (entry.isDirectory()) await walk(name);
      else if (/\.(dart|kt|xml|png)$/.test(name)) files.push(name);
    }
  }
  await walk('lib');
  await walk('android/app/src/main/kotlin');
  await walk('android/app/src/main/res');
  const hashes = {};
  for (const file of files.sort()) hashes[file] = sha256(await fs.readFile(path.join(root, file)));
  const combined = Object.entries(hashes).map(([file, hash]) => file + '\0' + hash + '\n').join('');
  return {sha256: sha256(combined), files: hashes};
}

module.exports = {runtimeFingerprint, sha256};
