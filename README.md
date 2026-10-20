# Game Tools

An Android gaming companion built with FVM Flutter 3.41.2.

## Features

- This app's cache: read and clear Game Tools' temporary cache, showing before, cleared, and remaining bytes. Preferences and game data are preserved.
- Open game library: opens installed-game shortcuts without clearing cache, changing Do Not Disturb, or requesting overlay/Usage Access.
- Network Latency: five TCP connection probes on the active Android network to Cloudflare 1.1.1.1:443. Shows measured average/minimum/maximum latency, consecutive-probe jitter, and failed probes.
- Top five caches: Usage Access permits reading cache sizes for launcher-visible apps on Android 8+. Cleanup of other apps is manual in Android App Info.
- Do Not Disturb: independently controlled, optional strict mode with explicit consent, real system status and a manual off toggle.
- App settings: opens Android's app settings. This action does not close recent apps, stop other apps, or change their settings.
- Device telemetry: screen refresh rate in Hz, battery percentage and battery temperature. No game FPS readings or performance scores.
- Display & games: Android display settings and installed-game launcher.
- Display monitor: optional overlay controlled by Usage Access and Display over other apps permission. Shows display refresh rate in Hz.
- Privacy policy: accessible in the app and as a standalone HTML page in `docs/index.html`.

## Limits

TCP connection latency is not ICMP ping, game-server ping, a speed test, or a network accelerator. Results are measured connection timings.

Android does not allow an ordinary app to clear other apps' private caches, force-stop every background app, clear Recent Apps, change another game's graphics configuration, or read another game's actual FPS. Cache cleanup can legitimately report 0 B when this app has no temporary files.

Strict Do Not Disturb silences alarms and media as well as notifications. WhatsApp and other calls may still arrive or appear. Android 15+ manages the app's request separately; other active rules may keep Do Not Disturb enabled after this app's request is turned off.

## Development

```powershell
fvm install 3.41.2
fvm flutter pub get
fvm flutter run
fvm flutter analyze
fvm flutter test
```

Native cache tests can be run from the `android` directory with `./gradlew.bat :app:testDebugUnitTest`. No APK needs to be packaged for the unit tests.

Before release, verify the network check on Wi-Fi, mobile data, VPN, offline, and network-switch scenarios on Android. Check cache cleanup with empty/populated cache directories, deny/grant/revoke Usage Access, and confirm Do Not Disturb restoration with existing system rules.

## Store Materials

The current localized listing package is in `play_store/latest`. See `play_store/latest/README.md` for all 29 locales, shared upload images, default/custom listing instructions, capture provenance and privacy-policy hosting. The Android package ID is unchanged.

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
