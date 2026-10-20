const fs = require('node:fs/promises');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const {runtimeFingerprint, sha256} = require('./store_runtime.cjs');

function run(executable, args) {
  const result = spawnSync(executable, args, {encoding: 'utf8', maxBuffer: 20 * 1024 * 1024});
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error((result.stderr || result.stdout || executable + ' failed').trim());
  return result.stdout.trim();
}

async function main() {
  const root = path.resolve(__dirname, '..');
  const [bundleArgument, expectedCode] = process.argv.slice(2);
  if (!bundleArgument || !/^\d+$/.test(expectedCode || '')) {
    throw new Error('Usage: node scripts/verify_android_bundle.cjs <AAB> <expected-version-code>');
  }
  const bundle = path.resolve(bundleArgument);
  const javaHome = process.env.BUNDLE_JAVA_HOME || 'C:/Program Files/Android/Android Studio/jbr';
  const java = path.join(javaHome, 'bin/java.exe');
  const tool = path.join(root, 'build/tools/bundletool-all-1.18.3.jar');
  const expectedToolHash = 'a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29';
  if (sha256(await fs.readFile(tool)) !== expectedToolHash) throw new Error('Unexpected bundletool binary.');
  run(java, ['-jar', tool, 'validate', '--bundle=' + bundle]);
  const attribute = xpath => run(java, ['-jar', tool, 'dump', 'manifest', '--bundle=' + bundle, '--module=base', '--xpath=' + xpath]);
  const appPackage = attribute('/manifest/@package');
  const versionCode = attribute('/manifest/@android:versionCode');
  const versionName = attribute('/manifest/@android:versionName');
  const label = attribute('/manifest/application/@android:label');
  if (appPackage !== 'com.deploydulupulangnanti.gameboosterpro') throw new Error('Unexpected package ID.');
  if (versionCode !== expectedCode || versionName !== '1.0.0') throw new Error('Unexpected release version.');
  if (label !== 'Game Tools') throw new Error('Unexpected application label.');
  const signature = run(path.join(javaHome, 'bin/jarsigner.exe'), ['-J-Duser.language=en', '-verify', '-certs', bundle]);
  if (!/jar verified/i.test(signature) || /jar is unsigned|unsigned entries/i.test(signature)) {
    throw new Error('The bundle is not fully signed.');
  }
  const certificate = run(path.join(javaHome, 'bin/keytool.exe'), ['-J-Duser.language=en', '-printcert', '-jarfile', bundle]);
  if (/CN=Android Debug/i.test(certificate)) throw new Error('A debug certificate cannot be used for this release.');
  const signerSha256 = certificate.match(/SHA256:\s*([0-9A-F:]+)/i)?.[1];
  if (!signerSha256) throw new Error('Could not identify signer certificate.');
  const runtime = await runtimeFingerprint(root);
  const capture = JSON.parse(await fs.readFile(path.join(root, 'play_store/latest/capture-provenance.json'), 'utf8'));
  if (runtime.sha256 !== capture.runtime.sha256) throw new Error('Release source no longer matches captured UI.');
  const directory = path.join(root, 'build/release-review');
  await fs.mkdir(directory, {recursive: true});
  const deliveredBundle = path.join(directory, 'game-tools-' + versionName + '-' + versionCode + '.aab');
  if (bundle !== path.resolve(deliveredBundle)) await fs.copyFile(bundle, deliveredBundle);
  const bytes = await fs.readFile(deliveredBundle);
  const report = {
    verifiedAtUtc: new Date().toISOString(), appPackage, label, versionName, versionCode,
    bundle: deliveredBundle, bytes: bytes.length, sha256: sha256(bytes),
    signatureVerified: true, debugCertificate: false, signerSha256,
    runtimeSha256: runtime.sha256,
    consoleUploadKeyMatchVerified: false, consoleVersionCodeAvailabilityVerified: false,
    androidDeviceVerified: false, consoleSubmitted: false,
  };
  await fs.writeFile(path.join(directory, 'release-verification.json'), JSON.stringify(report, null, 2) + '\n');
  await fs.writeFile(path.join(root, 'play_store/latest/release-verification.json'), JSON.stringify({
    ...report, bundle: path.basename(deliveredBundle),
  }, null, 2) + '\n');
  console.log(JSON.stringify(report, null, 2));
}

main().catch(error => {console.error(error.message); process.exitCode = 1;});
