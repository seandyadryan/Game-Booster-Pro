# Game Booster Pro

An Android gaming companion built with FVM Flutter 3.41.2.

## Features

- App cache: read and clear Game Booster Pro's temporary cache, showing before, cleared, and remaining bytes. Preferences and game data are preserved.
- Boost Now: launch the rocket animation, clean this app's cache, and start a session independently of optional Dont Disturb access.
- AI Network: five TCP connection probes on the active Android network to Cloudflare 1.1.1.1:443. Shows measured average/minimum/maximum latency, consecutive-probe jitter, and failed probes.
- Top five caches: Usage Access permits reading cache sizes for launcher-visible apps on Android 8+. Cleanup of other apps is manual in Android App Info.
- Dont Disturb: optional strict mode, real system status, and restoration of the app's own request at session end.
- Device telemetry: display refresh rate in Hz, battery percentage, and battery temperature.
- GFX Tools: Android display settings and installed-game launcher.
- Game monitor: optional overlay controlled by Usage Access and Display over other apps permission. Shows refresh Hz and unavailable game FPS.
- Privacy policy: accessible in the app and as a standalone HTML page in `docs/index.html`.

## Limits

TCP connection latency is not ICMP ping, game-server ping, a speed test, or a network accelerator. The AI Network name identifies the diagnostic panel; results are measured, not produced by an AI model.

Android does not allow an ordinary app to clear other apps' private caches, force-stop every background app, clear Recent Apps, change another game's graphics configuration, or read another game's actual FPS. Cache cleanup can legitimately report 0 B when this app has no temporary files.

Strict Dont Disturb silences alarms and media as well as notifications. WhatsApp and other calls may still arrive or appear. Android 15+ manages the app's request separately; other active rules may keep Dont Disturb enabled after a session.

## Development

```powershell
fvm install 3.41.2
fvm flutter pub get
fvm flutter run
fvm flutter analyze
fvm flutter test
```

Native cache tests can be run from the `android` directory with `./gradlew.bat :app:testDebugUnitTest`. No APK needs to be packaged for the unit tests.

Before release, verify the network check on Wi-Fi, mobile data, VPN, offline, and network-switch scenarios on Android. Check cache cleanup with empty/populated cache directories, deny/grant/revoke Usage Access, and confirm Dont Disturb restoration with existing system rules.

## Store Materials

English listing descriptions and upload assets are in `play_store`. See `play_store/README.md` for dimensions, limits, capture provenance, and privacy-policy hosting.

Developer: PT Deploy Dulu Pulang Nanti

Support: seandyadryan2@gmail.com

## Git Hook

The `.githooks/pre-commit` hook increments the build number in `pubspec.yaml` on every commit. Enable it with:

```powershell
git config core.hooksPath .githooks
```

## Release Signing

Local signing files are stored outside the repository:

```text
D:\KEYSTORE\game_booster.jks
D:\KEYSTORE\game_booster_key.properties
```

Keystore files and passwords are not committed.
