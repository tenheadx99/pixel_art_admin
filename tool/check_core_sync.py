#!/usr/bin/env python3
"""Guard against drift between the app and the admin panel's mirrored core.

The admin panel intentionally duplicates the app's conversion algorithm and
the PixelArt JSON wire format (the app repo must not depend on this project).
If either side changes without the other, admin-published artwork would stop
matching what the app produces — silently. This script fails when the
mirrored pieces diverge.

Usage: python3 tool/check_core_sync.py [--app-repo PATH]
Run it after touching either project's core files (or wire it into CI).
"""

import argparse
import re
import sys
from pathlib import Path

ADMIN_ROOT = Path(__file__).resolve().parents[1]

# (app-relative path, admin-relative path) pairs whose CODE must match.
MIRRORED = [
    (
        "lib/data/services/image_processing_service.dart",
        "lib/core/services/image_processing_service.dart",
    ),
]

# Critical serialization methods that must match in the PixelArt model
# (the admin copy legitimately lacks the app's caching helpers, so only the
# wire format is compared).
MODEL_PAIR = (
    "lib/data/models/pixel_art.dart",
    "lib/core/models/pixel_art.dart",
)
MODEL_METHODS = ["toJson", "fromJson"]


def normalize(code: str) -> list[str]:
    """Strip comments and blank lines so doc tweaks don't count as drift."""
    code = re.sub(r"//[^\n]*", "", code)
    code = re.sub(r"/\*.*?\*/", "", code, flags=re.S)
    return [line.strip() for line in code.splitlines() if line.strip()]


def extract_method(code: str, name: str) -> str:
    """Extract a method/factory body by brace matching."""
    match = re.search(rf"\b{name}\s*\(", code)
    if not match:
        return ""
    start = code.index("{", match.start())
    depth = 0
    for i in range(start, len(code)):
        if code[i] == "{":
            depth += 1
        elif code[i] == "}":
            depth -= 1
            if depth == 0:
                return code[match.start(): i + 1]
    return ""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--app-repo",
        default=str(ADMIN_ROOT.parent / "pixel_art_app"),
    )
    args = parser.parse_args()
    app_repo = Path(args.app_repo).resolve()

    failures = []

    for app_rel, admin_rel in MIRRORED:
        app_code = normalize((app_repo / app_rel).read_text())
        admin_code = normalize((ADMIN_ROOT / admin_rel).read_text())
        if app_code != admin_code:
            failures.append(f"{app_rel} <-> {admin_rel} differ")

    app_model = (app_repo / MODEL_PAIR[0]).read_text()
    admin_model = (ADMIN_ROOT / MODEL_PAIR[1]).read_text()
    for method in MODEL_METHODS:
        a = normalize(extract_method(app_model, method))
        b = normalize(extract_method(admin_model, method))
        if a != b:
            failures.append(f"PixelArt.{method} differs between app and admin")

    if failures:
        print("CORE DRIFT DETECTED — admin output may no longer match the app:")
        for f in failures:
            print(f"  !! {f}")
        sys.exit(1)
    print("core in sync: quantization pipeline and PixelArt wire format match")


if __name__ == "__main__":
    main()
