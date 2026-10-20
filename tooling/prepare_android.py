#!/usr/bin/env python3
"""Force compileSdk 35 and write optional widget resources."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / "android"
APP = ANDROID / "app"
RES = APP / "src" / "main" / "res"

def patch_sdk() -> None:
    if not ANDROID.exists():
        print("android/ missing")
        return
    for f in ANDROID.rglob("build.gradle*"):
        t = f.read_text(encoding="utf-8")
        orig = t
        # replace any compileSdk / targetSdk assignment (including flutter.xxxVersion)
        t = re.sub(
            r"compileSdk(?:Version)?\s*=\s*[^\n]+",
            "compileSdk = 35",
            t,
        )
        t = re.sub(
            r"compileSdkVersion\s+[^\n]+",
            "compileSdk 35",
            t,
        )
        t = re.sub(
            r"targetSdk(?:Version)?\s*=\s*[^\n]+",
            "targetSdk = 35",
            t,
        )
        t = re.sub(
            r"targetSdkVersion\s+[^\n]+",
            "targetSdkVersion 35",
            t,
        )
        if t != orig:
            f.write_text(t, encoding="utf-8")
        print("patched", f)
        for line in f.read_text().splitlines():
            if "compileSdk" in line or "targetSdk" in line:
                print(" ", line.strip())

def main() -> None:
    patch_sdk()
    print("SUCCESS prepare_android done")

if __name__ == "__main__":
    main()
