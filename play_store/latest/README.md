# Game Tools: Network & Cache

Current package: com.deploydulupulangnanti.gameboosterpro

Developer: PT Deploy Dulu Pulang Nanti

Support: seandyadryan2@gmail.com

## Included Materials

- metadata/: title, short description and full description in all 28 requested locales plus en-US.
- ALL_LANGUAGES.md: the same text in one document, preserving each language's opening and closing tags.
- assets/feature-graphic.png: 1024 x 500 PNG.
- assets/app-icon.png: 512 x 512 PNG.
- assets/phone/: five 1080 x 1920 screenshots.
- assets/desktop/: five 1920 x 1080 large-screen renders.
- capture-provenance.json: matching runtime source and screenshot hashes, with renderer limitations.
- SUBMISSION_CHECKLIST.md: rejection diagnosis, functionality boundaries and required Console steps.
- reviewer-notes-en-US.txt: accurate functionality explanation for review.
- privacy/index.html: current policy with the new name.
- asset-validation.json: character counts, image dimensions, file sizes and hashes.
- custom-store-listings/apply-to-existing-listings.json: locale-to-material mapping for existing custom store listings.

Each title is at most 30 characters, each short description at most 80, and each full description at most 4,000.

## Apply the Default Listing

Use the matching locale's text files in the default store listing. The app's interface remains English; every description discloses this. The shared images are therefore in English and can be reused for these locales.

Replace the old title, descriptions, icon, feature graphic and screenshots. Remove old screenshots with Boost Now, AI Network, GFX Tools, Connected/Disconnected sessions, or the FPS placeholder. Do not mix these new images with superseded promotional media.

## Apply Every Existing Custom Store Listing

This package has not been uploaded to Play Console. No authenticated inventory of your custom listing IDs, targeting rules, names, or languages was available. The mapping file is an application plan, not evidence of completed remote edits.

In Play Console, review each existing custom store listing, including country-, campaign- and URL-targeted variants. For each language, apply the corresponding metadata/<locale> text and the shared assets. Review inherited fields as well as fields overridden by the custom listing. Preserve its targeting unless you intend to change it.

Custom store listings do not automatically translate your content. Add each needed translation explicitly through Manage translations / Manage your own translations. If a listing belongs to a group, review the group's shared assets and any listing-specific overrides.

Also check experiments or other active variants that may still serve old titles or media. Use the new materials consistently across all affected variants, preview the rendered listing, then submit the changes for review.

## Match the Release

These screenshots were captured from the revised Flutter widgets in this repository. They show Start Session, Network Latency, This app's cache, App settings, Display & games, and session Active/Inactive. Animation FPS is explicitly labeled This app only; the panel measures only the test animation. The separate optional game display bar shows only display refresh rate in Hz. The original rocket session artwork is retained.

The capture renderer does not execute Android-native APIs. No fake latency, battery, cache savings or FPS measurements were inserted. For verified device telemetry, replace captures with screenshots from the matching release running on Android.

The desktop images show the responsive Flutter layout; they do not certify Google Play Games on PC or Windows support. Use only image categories supported by your actual distribution.

Upload a matching new Android App Bundle before using screenshots of changed UI for review. This task does not build or upload an APK/AAB. Updating listing copy alone does not change an already uploaded app.

## Policy and Artwork Notes

The new presentation describes a utility: TCP connection timings, app-owned temporary cache, game shortcuts, display settings and optional Do Not Disturb. It makes no claim to raise FPS, optimize a game's graphics, accelerate the network, or silently clear other apps' caches.

Feature graphic and icon artwork were made with the built-in imagegen tool. The banner's exact copy is "Game Tools: Network & Cache" and "Network latency. App cache. Game launcher." The artwork shows a controller, Wi-Fi and storage utilities without a speedometer, rocket, performance numbers or rankings. Mechanical resizing preserves the copy.

Screenshots come from the actual Flutter interface, not generated UI illustrations. Source fingerprints and image hashes guard against accidentally packaging older captures. They do not verify an uploaded binary or an existing Play Console listing. Reviewer acceptance remains Google's decision. Policy references:

- https://support.google.com/googleplay/android-developer/answer/17006354?hl=en
- https://support.google.com/googleplay/android-developer/answer/9898842?hl=en
- https://support.google.com/googleplay/android-developer/answer/9867158?hl=en
