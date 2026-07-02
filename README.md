# Pixel Art Admin

Standalone Flutter **web** admin panel for the pixel art app suite (Pixely,
Divine Pixels, Anime Pixels, PixelCalm, Gem Art). Lives entirely outside the
app repo — `pixel_art_app` is never modified by this project.

Manages, **per flavor**, in Firestore (project `om108-5c015`):

| Section  | What it controls                                                            | Firestore location                     |
|----------|-----------------------------------------------------------------------------|----------------------------------------|
| Ads      | show/hide ads, 4 AdMob unit IDs, pacing cooldowns                           | `pixel_art/{flavor}/config/ads`        |
| Economy  | diamond rewards, shop prices, ad/IAP grants, XP curve, milestones           | `pixel_art/{flavor}/config/economy`    |
| App      | minimum version + force-update URL                                          | `pixel_art/{flavor}/config/app`        |
| Artworks | hide/show, premium flag, category of bundled art; upload/delete remote art  | `.../artworks`, `.../overrides`        |
| Creator  | PNG/JPG → pixel-art conversion (same algorithm as the app) and publish      | `pixel_art/{flavor}/artworks`          |

Every catalog mutation bumps `pixel_art/{flavor}.catalogVersion` so clients
can cheaply detect changes.

## One-time setup

1. **Firestore + Auth** — in the [Firebase console](https://console.firebase.google.com/project/om108-5c015):
   enable Cloud Firestore and Email/Password authentication.
2. **Admin account** — create a user in Authentication, copy its UID, then
   create doc `pixel_art_admins/{uid}` with field `email`. Only allowlisted
   UIDs can write (enforced by `firestore.rules`).
3. **Rules** — the shared project may already have Firestore rules from other
   apps; merge them into `firestore.rules` first, then:
   `firebase deploy --only firestore:rules`
4. **Seed bundled catalog** — see [tool/README.md](tool/README.md).
5. **Hosting (optional)** — create a hosting site, then:
   ```bash
   firebase hosting:sites:create pixel-admin   # once
   firebase target:apply hosting pixel-admin pixel-admin
   flutter build web && firebase deploy --only hosting:pixel-admin
   ```

## Run locally

```bash
flutter run -d chrome
```

## App integration (future work — requires an app release)

The mobile apps currently read ads/app config from Firebase Remote Config and
ship artwork as bundled assets. For this panel to take effect, the app must
add `cloud_firestore` and:

- resolve config as **Firestore → Remote Config → built-in default**
  (extend `remote_config_service.dart`),
- read economy values from `config/economy` instead of `AppConstants`,
- sync `artworks` (where `visible == true`) + `overrides` when
  `catalogVersion` grows, cached locally, merged with the bundled catalog.

The Firestore paths/doc shapes are defined in `lib/core/schema/` — mirror
them in the app. Until then, the panel manages data the apps don't read yet;
ads can still be toggled via Remote Config in the Firebase console.

## Layout

- `lib/core/` — mirrors of the app's model/algorithms (PixelArt JSON contract,
  quantization, preview painters incl. gem style, flavor ids). Keep in sync
  with the app.
- `lib/services/` — Firestore CRUD (`catalog_service.dart` is the only writer
  of catalog collections; it enforces the `rmt_` id prefix and version bumps).
- `lib/screens/` — one screen per section, all scoped to the flavor selected
  in the top bar.
- `tool/` — Firestore seeding (reads the app repo read-only).
