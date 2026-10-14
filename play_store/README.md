# English Store Listing

App: Game Booster Pro

Developer: PT Deploy Dulu Pulang Nanti

Support: seandyadryan2@gmail.com

Package: com.deploydulupulangnanti.gameboosterpro

## Upload Files

- `short-description.txt`: English short description, maximum 80 characters.
- `full-description.txt`: English full description, maximum 4,000 characters.
- `feature-graphic.png`: PNG, exactly 1024 x 500, below 15 MB.
- `phone/`: four PNG screenshots, 1080 x 1920, 9:16, below 8 MB each.
- `desktop/`: four PNG screenshots, 1920 x 1080, 16:9, below 8 MB each.
- `asset-validation.json`: exact character counts, dimensions, and file sizes.

Upload numbered screenshots in order. They show the dashboard, tool grid, GFX Tools, and AI Network.

Screenshots are captures of the real Flutter widgets, not stock photos or AI-generated app interfaces. Native Android readings are intentionally unavailable during these renderer captures; no sample ping, FPS, cache savings, or battery values were invented. For screenshots showing live Android measurements, replace them with captures from the release on a physical Android device. Desktop images show the responsive large-screen layout and do not certify Windows or Google Play Games on PC support; use that upload category only for a supported target.

The feature graphic uses generated brand artwork, not a performance report. Its English copy is: "Game Booster Pro", "Your gaming companion", and "Cache tools. Network checks. Game launcher." It was generated with the built-in imagegen tool using the existing app icon as a visual reference, then fitted to the required dimensions without cropping the copy.

## Privacy Policy

`../docs/index.html` is the standalone English privacy policy. `../assets/privacy-policy.txt` is generated from the same document for in-app access through the header's Privacy policy button.

Host `docs/index.html` at a public HTTPS URL before entering the privacy-policy URL in Play Console. For GitHub Pages, configure this repository's `main` branch and `/docs` directory. This task creates the document; it does not configure public hosting.

The policy describes local cache and usage-event processing, optional Android permissions, the Cloudflare endpoint contacted by network checks, and support email. Ensure the Play Console Data safety answers match the release and any SDKs added later. In particular, do not claim that the app never connects to third parties: AI Network makes user-requested TCP probes, exposing connection metadata to the destination and network operators.

## Reproduction

With Flutter 3.41.2, render screenshots with:

```powershell
fvm flutter test tool/capture_play_store_test.dart --reporter expanded
```

The capture tool loads Roboto fonts from the local FVM 3.41.2 SDK. Update the font location if that SDK is installed elsewhere.

Export updated policy text with Python:

```powershell
python scripts/export_privacy_text.py
```

With Node.js and Sharp available, validate assets and listing lengths:

```powershell
node scripts/validate_play_store.cjs
```

`scripts/check_privacy_page.cjs` uses Playwright and Chrome to check the policy's mobile and desktop layout.
