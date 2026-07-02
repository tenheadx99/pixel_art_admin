# Admin tooling

## seed_firestore.py

Mirrors the app's bundled artwork catalogs (read-only — nothing in
`pixel_art_app` is modified) into the admin-only
`pixel_art/{flavor}/bundled_index` subcollections and creates each flavor's
root doc (`catalogVersion`). The admin panel lists bundled art from this
mirror; the mobile apps never read it (they have the assets).

```bash
pip install firebase-admin

# Authenticate (one of):
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
#   Firebase console -> Project settings -> Service accounts -> Generate new private key
# or:
gcloud auth application-default login

# Preview without writing:
python3 tool/seed_firestore.py --dry-run

# Seed everything / one flavor:
python3 tool/seed_firestore.py
python3 tool/seed_firestore.py --flavor diamond
```

Re-run whenever bundled content in the app changes. Idempotent — existing
`catalogVersion` values are never reset.

Config docs (`config/ads`, `config/app`, `config/economy`) are intentionally
NOT seeded: an absent doc/field means "no override" and the app keeps using
Remote Config / built-in defaults. They are created the first time you press
Save in the admin panel.
