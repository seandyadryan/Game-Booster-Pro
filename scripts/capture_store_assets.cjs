const fs = require('node:fs/promises');
const path = require('node:path');
const os = require('node:os');
const {spawnSync} = require('node:child_process');
const {runtimeFingerprint, sha256} = require('./store_runtime.cjs');

async function main() {
  const root = path.resolve(__dirname, '..');
  const before = await runtimeFingerprint(root);
  const flutter = process.env.FLUTTER_BIN || path.join(os.homedir(), 'fvm/versions/3.41.2/bin/flutter.bat');
  const command = `& '${flutter.replaceAll("'", "''")}' test --no-pub tool/capture_play_store_test.dart`;
  const result = spawnSync('powershell.exe', ['-NoProfile', '-Command', command], {
    cwd: root, env: {...process.env, CAPTURE_OUTPUT: 'play_store'}, stdio: 'inherit',
  });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('Flutter screenshot capture failed.');
  const after = await runtimeFingerprint(root);
  if (before.sha256 !== after.sha256) throw new Error('Runtime source changed during capture; rerun.');
  const screenshots = {};
  for (const group of ['phone', 'desktop']) {
    for (const name of ['01-dashboard', '02-tools', '03-display-game-tools', '04-network-latency', '05-dnd-consent']) {
      const file = group + '/' + name + '.png';
      screenshots[file] = sha256(await fs.readFile(path.join(root, 'play_store', file)));
    }
  }
  const provenance = {
    generatedAtUtc: new Date().toISOString(),
    method: 'Actual Flutter widget renderer; not Android device captures.',
    nativeTelemetry: 'Unavailable. No invented cache savings, latency, battery or game FPS readings.',
    runtime: after,
    screenshots,
    androidDeviceVerified: false,
    consoleApplied: false,
  };
  await fs.writeFile(path.join(root, 'play_store/capture-provenance.json'), JSON.stringify(provenance, null, 2) + '\n');
  console.log('Captured 10 screenshots and recorded matching runtime/image hashes.');
}

main().catch(error => {console.error(error.message); process.exitCode = 1;});
