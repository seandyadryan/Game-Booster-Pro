# Current Store Listing

The current listing title is **Game Tools: Network & Cache**.

Use [latest/README.md](latest/README.md) for the current 29-language upload package, images, privacy policy and default/custom listing instructions. The ZIP deliverable is game-tools-store-listing-latest.zip in this directory.

The current English fields are also available as title.txt, short-description.txt and full-description.txt. Canonical translations are stored in listing-source.json. Each locale has a title, short description and full description. The app interface and shared images are in English, as disclosed in every description.

Current screen captures use Start Session, Network Latency, This app's cache, Display & games, and session Active/Inactive. The display monitor shows only refresh rate in Hz. The icon and feature graphic use the new Game Tools identity.

Older release-note files refer to their historical release and are not part of the latest upload bundle. Previous promotional assets under assets/play_store are superseded. Do not upload them together with this package.

## Reproduce

Render the actual Flutter widgets with FVM Flutter 3.41.2:

    fvm flutter test tool/capture_play_store_test.dart --reporter expanded

With Node.js and Sharp available, package and validate all locales and current images:

    node scripts/package_listing.cjs
    node scripts/validate_play_store.cjs

Prepare the artwork with scripts/prepare_brand_assets.cjs, passing the generated feature image and icon paths. That script resizes the artwork and updates launcher PNGs. It does not generate app screenshots.

Export in-app policy text from docs/index.html with scripts/export_privacy_text.py. Browser layout checks are in scripts/check_privacy_page.cjs.

The screenshot renderer does not execute Android-native APIs and supplies no invented telemetry. Test the matching Android release on a device before resubmission. The current package has not been applied to Play Console; the custom-store-listing inventory and remote edits require an authenticated account.
