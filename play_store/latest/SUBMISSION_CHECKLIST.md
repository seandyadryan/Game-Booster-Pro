# Deceptive Behavior Remediation - October 19, 2026

Package: com.deploydulupulangnanti.gameboosterpro

Developer: PT Deploy Dulu Pulang Nanti

Support: seandyadryan2@gmail.com

## What the Rejection Shows

Google identifies the Indonesian full description and APP_SCREENSHOT-8148.png. That screenshot shows Game Booster Pro, BOOST NOW and AI Network. The quoted description uses another brand, Game Mode PRO: Launcher & FPS, and promises game controls, clearing recent apps, graphics controls and full control of game settings.

These are not a precise description of the implementation. The rejection does not identify one specific word as the sole cause. Merely adding a disclaimer or changing the store title is not sufficient if other material or the uploaded binary still implies unsupported behavior.

The local interface now says Game Tools, Start Session, Network Latency, This app's cache, App settings and Animation FPS / This app only. The original rocket illustration is preserved as cosmetic artwork, not a promise of performance acceleration.

## Exact Listing to Use

English title: Game Tools: Network & Cache

Indonesian title: Game Tools: Jaringan & Cache

Use metadata/en-US for English and metadata/id for Indonesian. Other requested translations are in the other metadata folders. ALL_LANGUAGES.md contains all 29 locales with language tags. Every description discloses the English interface.

Do not submit a title containing FPS, AI, Booster, GFX or Game Mode. Animation FPS is a test of this app's animation, not a primary game-monitoring feature. The full descriptions explain its narrow scope.

## Functionality Boundaries

| Control | What it actually does | What it does not do |
| --- | --- | --- |
| Start Session | Clears this app's own temporary cache; optionally requests Do Not Disturb with consent | Does not increase game performance, RAM capacity or game FPS |
| This app's cache | Reports cache before, removed and remaining bytes, including 0 B | Does not automatically erase other apps' private caches |
| Top-five cache list | Uses Usage Access to read available cache sizes; links to Android App Info | Usage Access does not grant permission to clear another app's cache |
| Network Latency | Measures five TCP connections to Cloudflare 1.1.1.1:443 | No AI, acceleration, game-server ping or Internet speed measurement |
| App settings | Opens Android app settings | No closing Recent Apps, force-stopping or automatic background cleanup |
| Display & games | Opens Android display settings or launches an installed game | Does not modify a game's resolution, graphics or FPS limit |
| Display bar | Shows screen refresh rate in Hz with optional permissions | Not the game's rendered FPS; not a battery/temperature overlay |
| Animation FPS | Estimates frame cadence of this app's test animation using Flutter frame timings | No other-game FPS measurement or game FPS overlay |
| Battery dashboard | Reads available battery percentage and temperature in this app | Not CPU/GPU temperature; no cooling or battery-health repair |
| Do Not Disturb | Requests system Do Not Disturb after consent; can silence alarms and media | Does not reject incoming WhatsApp or other calls |

## Apply Before Resubmitting

1. Build a new signed Android App Bundle from this corrected source with FVM Flutter 3.41.2. Keep the package ID above and the existing upload key. Its version code must be greater than every previously uploaded version; a local +1 hook alone cannot verify the highest Play Console code.
2. Install the release through an internal test track and verify the displayed name, buttons, game launcher, optional permissions, network results, cache bytes and DND restoration. No physical-device verification or APK/AAB upload has been performed by the local listing scripts.
3. Capture actual screenshots on that tested Android release for the strongest evidence. Included phone images are real Flutter-widget renders, not device captures. Native readings are deliberately unavailable, not invented. Replace them if their state does not reflect your tested release.
4. In the default store listing, replace title, short/full descriptions, feature graphic and all old screenshots for every configured language. Pay particular attention to Indonesian (id), which is explicitly cited. Do not mix the rejected screenshot with new images.
5. Review EVERY custom store listing, listing group, translated field and experiment/variant. Replace inherited and overridden fields that still contain old claims. Custom listings do not auto-translate. Preserve targeting unless deliberately changing it. The included mapping has no authenticated listing inventory.
6. Check icon, promotional video, screenshot captions, release notes and external promotional pages for obsolete claims. The unchanged rocket must be presented only as decorative session artwork. Confirm you hold rights to all artwork; this task does not establish a license to the provided rocket.
7. Verify the live privacy-policy URL and Data safety answers against the binary. Network checks contact Cloudflare; optional Usage Access/overlay/DND permissions must have accurate purposes and consent.
8. Preview each listing and confirm that the binary selected in the release is the new one, not the one shown in APP_SCREENSHOT-8148.png. A metadata edit does not update a previously uploaded binary.
9. Only then send the binary and listing changes together from Publishing overview. Use reviewer-notes-en-US.txt as a functionality explanation if useful. Do not claim this issue was a reviewer error without evidence.

## Assets and Evidence

- assets/feature-graphic.png: 1024 x 500, no speed/FPS/AI improvement claims.
- assets/phone/: five 1080 x 1920 UI captures, including the explicitly scoped Animation FPS panel.
- assets/desktop/: five 1920 x 1080 responsive renders. These do not prove desktop distribution or Play Games on PC support; do not upload into an unsupported device category.
- capture-provenance.json: runtime source and screenshot hashes, with explicit native/device verification limitations.
- asset-validation.json: all 29 locale field limits, dimensions, file sizes and image hashes.
- custom-store-listings/apply-to-existing-listings.json: a local application plan only, not evidence of Play Console updates.

The packaging script refuses source-mismatched or replaced screenshots and obsolete promotional labels. This detects local artifact mix-ups; it cannot inspect or verify what is selected in Play Console.

## Status and Policy References

Prepared locally. No Play Console listing, custom listing, release, review or appeal has been changed or submitted. No APK/AAB was built. Acceptance remains Google's decision, and fixing the observed mismatch does not guarantee approval.

- Deceptive Behavior: https://support.google.com/googleplay/android-developer/answer/17006354?hl=en
- Metadata: https://support.google.com/googleplay/android-developer/answer/9898842?hl=en
- Custom listings: https://support.google.com/googleplay/android-developer/answer/9867158?hl=en
