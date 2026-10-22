#!/usr/bin/env python3
"""Force compileSdk 35. Widget resources written but NOT registered in manifest (avoids aapt fail)."""
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]
TOOLING = Path(__file__).resolve().parent
APP = ROOT / "android" / "app"
RES = APP / "src" / "main" / "res"
KT = APP / "src" / "main" / "kotlin" / "ir" / "apadanasleep" / "customer_callbook"
MANIFEST = APP / "src" / "main" / "AndroidManifest.xml"


def patch_sdk() -> None:
    android = ROOT / "android"
    if not android.exists():
        print("no android dir")
        return
    for f in android.rglob("build.gradle*"):
        t = f.read_text(encoding="utf-8")
        orig = t
        t = re.sub(r"compileSdk(?:Version)?\s*=\s*[^\n]+", "compileSdk = 35", t)
        t = re.sub(r"compileSdkVersion\s+[^\n]+", "compileSdk 35", t)
        t = re.sub(r"targetSdk(?:Version)?\s*=\s*[^\n]+", "targetSdk = 35", t)
        t = re.sub(r"targetSdkVersion\s+[^\n]+", "targetSdkVersion 35", t)
        # also force in local.properties / flutter defaults if present
        if t != orig:
            f.write_text(t, encoding="utf-8")
        print("sdk", f)
        for line in f.read_text().splitlines():
            if "compileSdk" in line or "targetSdk" in line:
                print(" ", line.strip())


def main() -> None:
    if not APP.exists():
        raise SystemExit("android/app missing")

    # copy kotlin (call alert, phone receiver, main)
    KT.mkdir(parents=True, exist_ok=True)
    for name in (
        "MainActivity.kt",
        "PhoneStateReceiver.kt",
        "BootReceiver.kt",
        "CallAlertActivity.kt",
        "CallOverlayService.kt",
        "DaftarcheWidgetProvider.kt",
    ):
        src = TOOLING / name
        if src.exists():
            shutil.copy2(src, KT / name)
            print("kt", name)

    # widget resource files (for future enable; not referenced in manifest)
    for sub, name in [
        ("layout", "daftarche_widget.xml"),
        ("xml", "daftarche_widget_info.xml"),
        ("drawable", "widget_bg.xml"),
    ]:
        src = TOOLING / "res" / sub / name
        if src.exists():
            dst = RES / sub / name
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            print("res", dst)

    # manifest WITHOUT widget receiver
    shutil.copy2(TOOLING / "AndroidManifest.xml", MANIFEST)
    text = MANIFEST.read_text(encoding="utf-8")
    if "daftarche_widget_info" in text:
        raise SystemExit("BUG: manifest still references widget xml")
    if "PhoneStateReceiver" not in text:
        raise SystemExit("BUG: PhoneStateReceiver missing from manifest")
    if "CallAlertActivity" not in text:
        raise SystemExit("BUG: CallAlertActivity missing from manifest")
    print("manifest OK (no widget ref)")

    patch_sdk()
    print("SUCCESS prepare_android")


if __name__ == "__main__":
    main()
