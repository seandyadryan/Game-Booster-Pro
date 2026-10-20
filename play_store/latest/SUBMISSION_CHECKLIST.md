# Deceptive Behavior Remediation - October 20, 2026

Package: com.deploydulupulangnanti.gameboosterpro

Developer: PT Deploy Dulu Pulang Nanti

Support: seandyadryan2@gmail.com

## What Changed

The rejection screenshot still shows Game Booster Pro, BOOST NOW, App cache / Clear cache and Background / Manage apps. It is not the current interface. Google has not identified the rocket alone as the cause; the issue concerns claims and actual functionality across the app and its metadata.

The new implementation removes the session/boost flow and the animation FPS demo. The primary action is Open game library: it opens installed-game shortcuts, without cleanup, DND changes, performance scores or permission prompts. The rocket remains decorative navigation artwork. The app presents the same features to reviewers and ordinary users.

## Accurate Identity

English title: Game Tools: Network & Cache

Indonesian title: Game Tools: Jaringan & Cache

Use the matching metadata/<locale> files. ALL_LANGUAGES.md contains all 29 locales with tags. The interface is English. Do not reuse Game Booster Pro: FPS or Game Mode PRO: Launcher & FPS titles for this release.

## Actual Functionality

| Control | Actual behavior |
| --- | --- |
| Open game library / My games | Lists installed apps recognized as games and launches the selected package; no system changes or extra permissions |
| This app's cache | Explicitly removes this app's own temporary cache and reports actual before/removed/remaining bytes, including zero |
| Top 5 app caches | Reads available cache sizes after Usage Access on Android 8+; opens Android App Info for manual cleanup |
| Network Latency | Five user-requested TCP connections to Cloudflare 1.1.1.1:443; not AI, acceleration, game-server ping or a speed test |
| App settings | Opens Android settings; does not close Recent Apps or force-stop applications |
| Screen refresh rate | Reads screen Hz, not rendered game FPS |
| Display & games | Opens Android display settings or explicitly requests an optional screen-Hz overlay; cannot change another game's graphics |
| Battery dashboard | Displays battery percentage and temperature when available; no cooling, CPU/GPU monitoring or battery repair |
| Do Not Disturb | Explicit, consented toggle; can silence alarms/media but does not reject WhatsApp or other calls |

## Required Before Submission

1. Use a new signed AAB from this source, with the unchanged package ID and the correct registered upload key. Check the actual bundle version code against the highest code in Play Console. A local increment does not verify Console history.
2. Install the release through internal testing. Confirm the header is Game Tools and the main button is Open game library. BOOST NOW, Start Session, Session, Animation FPS and game-FPS claims must be absent.
3. Verify the chosen game package launches without Usage Access/overlay prompts by default and without cache or DND changes. Test the optional screen-Hz bar separately after disclosure and grants.
4. Verify cache cleanup with empty and populated app cache, network checks offline/on Wi-Fi/mobile data, settings shortcuts, and Do Not Disturb enable/disable/permission revocation on real Android devices. No physical-device verification is asserted by the screenshot renderer.
5. Replace the title, short/full descriptions, feature image and ALL old screenshots in every configured default-listing language, especially Indonesian (id).
6. Inspect every custom listing, listing group, country/campaign/URL variant, translated override and experiment. Replace old material there too. Custom listings do not auto-translate. No remote inventory has been supplied or updated here.
7. Remove old videos, captions, release notes and external promotional claims about boosting, clearing all caches/recent apps, AI acceleration, game FPS or controlling game graphics. Do not mix older ZIP contents with this package.
8. The supplied phone images are actual Flutter-widget captures without invented native readings. Capture the tested Android release itself for stronger evidence. Desktop renders do not establish PC support.
9. Publish the updated privacy HTML at your real public privacy URL and check Data safety answers against actual behavior. Network checks contact Cloudflare; optional permissions must retain accurate disclosure and user consent. Verify rights to the supplied rocket artwork.
10. In Publishing overview, confirm both the new binary and corrected listing changes are selected. Only then submit for review. Changing listing text alone does not replace an older binary. Approval is not guaranteed.

## Evidence and Status

capture-provenance.json records runtime and screenshot hashes; asset-validation.json records locale and image limits. These checks prevent local mixing of source/captures but cannot inspect an already uploaded binary or Play Console selection.

The corrected materials and source are local artifacts. No listing, custom listing, release, appeal or review has been submitted to Google by these scripts. See the delivered AAB and its verification output separately for build identity; a screenshot alone is not a release binary.

Policies:

- https://support.google.com/googleplay/android-developer/answer/17006354?hl=en
- https://support.google.com/googleplay/android-developer/answer/9898842?hl=en
- https://support.google.com/googleplay/android-developer/answer/9867158?hl=en
