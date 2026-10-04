#!/usr/bin/env python3
# ohos-kernel-port / tests/decode-blob.py
#
# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2026 ohos-kernel-port contributors
# SPDX-License-Identifier: GPL-2.0-only
#
# Decode a gitcode "contents" API response into the file it describes.
# The API returns base64 in a JSON envelope; the raw host serves an HTML
# interstitial instead, so the API is the only reliable way to fetch a single
# file from an OpenHarmony kernel tree.
#
# Usage: decode-blob.py <response.json> <output-path>

import base64
import json
import os
import sys


def main(argv):
    if len(argv) != 3:
        print(__doc__)
        return 2
    try:
        with open(argv[1], encoding="utf-8") as fh:
            doc = json.load(fh)
    except (OSError, ValueError) as exc:
        print(f"cannot read {argv[1]}: {exc}", file=sys.stderr)
        return 1
    if not isinstance(doc, dict) or "content" not in doc:
        print(f"{argv[1]} is not a contents response", file=sys.stderr)
        return 1
    try:
        blob = base64.b64decode(doc["content"])
    except Exception as exc:  # noqa: BLE001
        print(f"cannot decode content: {exc}", file=sys.stderr)
        return 1
    os.makedirs(os.path.dirname(argv[2]) or ".", exist_ok=True)
    with open(argv[2], "wb") as fh:
        fh.write(blob)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
