#!/usr/bin/env python3
"""Assemble an .icns file from an AppIcon.iconset directory.

The icns container format stores PNG data in typed chunks. Modern macOS
accepts the PNG chunk types used here (icp4/icp5/icp6/ic07/ic08/ic09/ic10).

Usage: make_icns.py <iconset-dir> <output.icns>
"""

import struct
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: make_icns.py <iconset-dir> <output.icns>", file=sys.stderr)
        return 2

    iconset = Path(sys.argv[1])
    output = Path(sys.argv[2])

    # (filename, icns chunk type)
    chunks = [
        ("icon_16x16.png", "icp4"),
        ("icon_16x16@2x.png", "icp5"),
        ("icon_32x32.png", "icp5"),
        ("icon_32x32@2x.png", "icp6"),
        ("icon_128x128.png", "ic07"),
        ("icon_128x128@2x.png", "ic08"),
        ("icon_256x256.png", "ic08"),
        ("icon_256x256@2x.png", "ic09"),
        ("icon_512x512.png", "ic09"),
        ("icon_512x512@2x.png", "ic10"),
    ]

    payload = b""
    for filename, chunk_type in chunks:
        path = iconset / filename
        if not path.exists():
            print(f"missing {filename}", file=sys.stderr)
            return 1
        data = path.read_bytes()
        payload += chunk_type.encode("ascii") + struct.pack(">I", len(data) + 8) + data

    icns = b"icns" + struct.pack(">I", len(payload) + 8) + payload
    output.write_bytes(icns)
    print(f"wrote {output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
