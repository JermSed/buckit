#!/usr/bin/env python3
"""Render the vector bucket mark into the app icon and menu bar assets."""

from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
assets = root / "Assets"

subprocess.run([
    "sips", "-s", "format", "png", str(assets / "buckit-mark.svg"),
    "--out", str(assets / "buckit-mark.png"),
], check=True, stdout=subprocess.DEVNULL)
subprocess.run([
    "sips", "-s", "format", "png", str(assets / "buckit-menu.svg"),
    "--out", str(assets / "buckit-menu.png"),
], check=True, stdout=subprocess.DEVNULL)
subprocess.run([
    "sips", "-Z", "64", str(assets / "buckit-menu.png"),
], check=True, stdout=subprocess.DEVNULL)

with tempfile.TemporaryDirectory(prefix="buckit-icons-") as directory:
    iconset = Path(directory) / "Buckit.iconset"
    iconset.mkdir()
    for points in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            suffix = "@2x" if scale == 2 else ""
            size = points * scale
            subprocess.run([
                "sips", "-z", str(size), str(size),
                str(assets / "buckit-mark.png"),
                "--out", str(iconset / f"icon_{points}x{points}{suffix}.png"),
            ], check=True, stdout=subprocess.DEVNULL)
    subprocess.run([
        "iconutil", "-c", "icns", str(iconset),
        "-o", str(assets / "Buckit.icns"),
    ], check=True)

print("Rendered Buckit.app and menu bar icons")
