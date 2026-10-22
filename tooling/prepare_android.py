#!/usr/bin/env python3
"""Copy single MainActivity.kt (contains all native classes) + force compileSdk 35."""
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]
TOOLING = Path(__file__).resolve().parent
APP = ROOT / "android" / "app"
KT = APP / "src" / "main" / "kotlin" / "ir" / "apadanasleep" / "customer_callbook"
MANIFEST = APP / "src" / "main" / "AndroidManifest.xml"


def patch_sdk() -> None:
    android = ROOT / "android"
    if not android.exists():
        return
    for f in android.rglob("build.gradle*"):
        t = f.read_text(encoding="utf-8")
        t = t.replace("compileSdk = flutter.compileSdkVersion", "compileSdk = 35")
        t = t.replace("targetSdk = flutter.targetSdkVersion", "targetSdk = 35")
        t = t.replace("compileSdk flutter.compileSdkVersion", "compileSdk 35")
        t = t.replace("targetSdk flutter.targetSdkVersion", "targetSdk 35")
        t = re.sub(r"compileSdk(?:Version)?\s*=\s*[^\n]+", "compileSdk = 35", t)
        t = re.sub(r"compileSdkVersion\s+[^\n]+", "compileSdk 35", t)
        t = re.sub(r"targetSdk(?:Version)?\s*=\s*[^\n]+", "targetSdk = 35", t)
        t = re.sub(r"targetSdkVersion\s+[^\n]+", "targetSdkVersion 35", t)
        if "compileSdk" not in t and "android {" in t:
            t = t.replace("android {", "android {\n    compileSdk = 35", 1)
        f.write_text(t, encoding="utf-8")
        print("sdk", f)
        for line in f.read_text().splitlines():
            if "compileSdk" in line or "targetSdk" in line:
                print(" ", line.strip())


def main() -> None:
    if not APP.exists():
        raise SystemExit("android/app missing")
    KT.mkdir(parents=True, exist_ok=True)

    src = TOOLING / "MainActivity.kt"
    if not src.exists():
        raise SystemExit("tooling/MainActivity.kt missing")
    text = src.read_text(encoding="utf-8")
    for cls in (
        "MainActivity",
        "CallMonitorService",
        "CallOverlayService",
        "CallAlertActivity",
        "PhoneStateReceiver",
        "BootReceiver",
    ):
        if f"class {cls}" not in text:
            raise SystemExit(f"class {cls} missing from MainActivity.kt")
    shutil.copy2(src, KT / "MainActivity.kt")
    print("MainActivity.kt copied, bytes", src.stat().st_size)

    # remove any stale separate kt files that could conflict
    for name in (
        "CallMonitorService.kt",
        "CallOverlayService.kt",
        "CallAlertActivity.kt",
        "PhoneStateReceiver.kt",
        "BootReceiver.kt",
        "DaftarcheWidgetProvider.kt",
    ):
        p = KT / name
        if p.exists():
            p.unlink()
            print("removed stale", name)

    shutil.copy2(TOOLING / "AndroidManifest.xml", MANIFEST)
    man = MANIFEST.read_text(encoding="utf-8")
    if "daftarche_widget_info" in man:
        raise SystemExit("widget still in manifest")
    for name in ("PhoneStateReceiver", "CallMonitorService", "CallOverlayService", "CallAlertActivity"):
        if name not in man:
            raise SystemExit(f"{name} missing from manifest")
    print("manifest OK")
    patch_sdk()
    print("SUCCESS prepare_android")


if __name__ == "__main__":
    main()
