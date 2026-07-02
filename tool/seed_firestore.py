#!/usr/bin/env python3
"""Seed Firestore for the pixel art admin panel.

Reads the app's bundled artwork assets (READ-ONLY — the app repo is never
modified) and mirrors them into the admin-only `bundled_index` subcollection,
plus creates each flavor's root doc with an initial catalogVersion.

Usage:
    pip install firebase-admin
    # Auth (either):
    #   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
    #   (Firebase console -> Project settings -> Service accounts -> Generate key)
    # or: gcloud auth application-default login
    python3 tool/seed_firestore.py [--app-repo PATH] [--flavor FLAVOR] [--dry-run]

Idempotent: re-running refreshes bundled_index docs in place and never
decreases catalogVersion. Run again whenever the app's bundled content
changes.
"""

import argparse
import json
import sys
from pathlib import Path

PROJECT_ID = "om108-5c015"

# flavor id -> bundled asset dir in the app repo (mirrors FlavorConfig).
FLAVOR_ASSET_DIRS = {
    "original": "assets/pixel_art",
    "devotional": "assets/pixel_art_devotional",
    "anime": "assets/pixel_art_anime",
    "pixelcalm": "assets/pixel_art_pixelcalm",
    "diamond": "assets/pixel_art_diamond",
}

ROOT_COLLECTION = "pixel_art"


def load_bundled_artworks(app_repo: Path, flavor: str):
    """Yield (manifest_index, artwork_json) for a flavor's bundled catalog."""
    asset_dir = app_repo / FLAVOR_ASSET_DIRS[flavor]
    manifest_path = asset_dir / "manifest.json"
    if not manifest_path.exists():
        print(f"  !! no manifest at {manifest_path}, skipping {flavor}")
        return
    manifest = json.loads(manifest_path.read_text())
    for index, rel_path in enumerate(manifest):
        art_path = app_repo / rel_path
        if not art_path.exists():
            print(f"  !! missing {rel_path} (listed in manifest), skipped")
            continue
        try:
            data = json.loads(art_path.read_text())
        except json.JSONDecodeError as e:
            print(f"  !! invalid JSON in {rel_path}: {e}, skipped")
            continue
        if "id" not in data or "grid" not in data:
            print(f"  !! {rel_path} lacks id/grid, skipped")
            continue
        yield index, data


def seed(app_repo: Path, flavors, dry_run: bool):
    if not dry_run:
        import firebase_admin
        from firebase_admin import firestore

        firebase_admin.initialize_app(options={"projectId": PROJECT_ID})
        db = firestore.client()
        server_ts = firestore.SERVER_TIMESTAMP
        increment0 = firestore.Increment(0)

    for flavor in flavors:
        print(f"== {flavor}")
        artworks = list(load_bundled_artworks(app_repo, flavor))
        print(f"   {len(artworks)} bundled artworks")
        if dry_run:
            for index, art in artworks:
                print(f"   [{index:3d}] {art['id']:32s} {art.get('category', '?')}")
            continue

        batch = db.batch()
        ops = 0
        for index, art in artworks:
            ref = (
                db.collection(ROOT_COLLECTION)
                .document(flavor)
                .collection("bundled_index")
                .document(art["id"])
            )
            batch.set(ref, {**art, "manifestIndex": index})
            ops += 1
            if ops >= 400:  # Firestore batch limit is 500 ops.
                batch.commit()
                batch = db.batch()
                ops = 0

        # Flavor root doc: create catalogVersion if absent, never decrease.
        flavor_ref = db.collection(ROOT_COLLECTION).document(flavor)
        if flavor_ref.get().exists:
            batch.set(
                flavor_ref,
                {"catalogVersion": increment0, "updatedAt": server_ts},
                merge=True,
            )
        else:
            batch.set(flavor_ref, {"catalogVersion": 1, "updatedAt": server_ts})
        batch.commit()
        print(f"   seeded {len(artworks)} docs into "
              f"{ROOT_COLLECTION}/{flavor}/bundled_index")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--app-repo",
        default=str(Path(__file__).resolve().parents[2] / "pixel_art_app"),
        help="Path to the pixel_art_app repo (read-only). "
             "Default: sibling ../pixel_art_app",
    )
    parser.add_argument(
        "--flavor",
        choices=sorted(FLAVOR_ASSET_DIRS),
        help="Seed a single flavor (default: all)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="List what would be uploaded without writing to Firestore",
    )
    args = parser.parse_args()

    app_repo = Path(args.app_repo).resolve()
    if not (app_repo / "pubspec.yaml").exists():
        sys.exit(f"error: {app_repo} does not look like the app repo "
                 f"(no pubspec.yaml)")

    flavors = [args.flavor] if args.flavor else list(FLAVOR_ASSET_DIRS)
    seed(app_repo, flavors, args.dry_run)
    print("done")


if __name__ == "__main__":
    main()
