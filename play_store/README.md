# Current Store Listing

The current listing title is **Game Tools: Network & Cache**.

Use [latest/README.md](latest/README.md) for the current 29-language upload package, images, privacy policy and default/custom listing instructions. The October 20 remediation ZIP is game-tools-policy-fix-2026-10-20.zip in this directory. Start with latest/SUBMISSION_CHECKLIST.md before submitting a new binary and listing together.

The current English fields are also available as title.txt, short-description.txt and full-description.txt. Canonical translations are stored in listing-source.json, with explicit feature limits in feature-limitations.json. Packaging combines both sources for each locale. The app interface and shared images are in English, as disclosed in every description.

Current captures use Open game library, Network Latency, This app's cache, App settings, Display & games and Screen refresh rate in Hz. Session state and the FPS demo have been removed. The rocket is unchanged decorative navigation artwork. Ordinary launching has no cleanup, DND changes or overlay/Usage Access requirement.

Older release-note files refer to their historical release and are not part of the latest upload bundle. Previous promotional assets under assets/play_store are superseded. Do not upload them together with this package.

## Reproduce

Render the actual Flutter widgets with FVM Flutter 3.41.2:

    node scripts/capture_store_assets.cjs

With Node.js and Sharp available, package and validate all locales and current images:

    node scripts/package_listing.cjs
    node scripts/validate_play_store.cjs

Prepare the artwork with scripts/prepare_brand_assets.cjs, passing the generated feature image and icon paths. That script resizes the artwork and updates launcher PNGs. It does not generate app screenshots.

Export in-app policy text from docs/index.html with scripts/export_privacy_text.py. Browser layout checks are in scripts/check_privacy_page.cjs.

The capture wrapper runs Flutter 3.41.2 and records source/screenshot hashes. Direct Flutter captures remain useful for inspection, but rerun the wrapper before packaging to refresh provenance. The screenshot renderer does not execute Android-native APIs and supplies no invented telemetry. Test the matching Android release on a device before resubmission. The current package has not been applied to Play Console; the custom-store-listing inventory and remote edits require an authenticated account.
