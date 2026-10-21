#!/usr/bin/env python3
"""Copy native pieces, widget resources, force compileSdk 35."""
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
        return
    for f in android.rglob("build.gradle*"):
        t = f.read_text(encoding="utf-8")
        orig = t
        t = re.sub(r"compileSdk(?:Version)?\s*=\s*[^\n]+", "compileSdk = 35", t)
        t = re.sub(r"compileSdkVersion\s+[^\n]+", "compileSdk 35", t)
        t = re.sub(r"targetSdk(?:Version)?\s*=\s*[^\n]+", "targetSdk = 35", t)
        t = re.sub(r"targetSdkVersion\s+[^\n]+", "targetSdkVersion 35", t)
        if t != orig:
            f.write_text(t, encoding="utf-8")
        print("sdk", f)


def main() -> None:
    if not APP.exists():
        raise SystemExit("android/app missing — run flutter create first")

    # resources
    for sub, name in [
        ("layout", "daftarche_widget.xml"),
        ("xml", "daftarche_widget_info.xml"),
        ("drawable", "widget_bg.xml"),
    ]:
        src = TOOLING / "res" / sub / name
        dst = RES / sub / name
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        print("res", dst, dst.stat().st_size)

    # kotlin
    KT.mkdir(parents=True, exist_ok=True)
    for name in (
        "MainActivity.kt",
        "DaftarcheWidgetProvider.kt",
        "PhoneStateReceiver.kt",
        "BootReceiver.kt",
        "CallAlertActivity.kt",
    ):
        src = TOOLING / name
        if src.exists():
            shutil.copy2(src, KT / name)
            print("kt", name)

    # manifest (with receivers)
    shutil.copy2(TOOLING / "AndroidManifest.xml", MANIFEST)
    print("manifest copied")

    # verify critical pieces
    info = RES / "xml" / "daftarche_widget_info.xml"
    if not info.exists() or info.stat().st_size < 40:
        raise SystemExit("widget xml missing")
    m = MANIFEST.read_text(encoding="utf-8")
    for needle in (
        "daftarche_widget_info",
        "DaftarcheWidgetProvider",
        "PhoneStateReceiver",
        "READ_PHONE_STATE",
        "READ_CALL_LOG",
        "POST_NOTIFICATIONS",
    ):
        if needle not in m:
            raise SystemExit(f"manifest missing {needle}")

    patch_sdk()
    print("SUCCESS prepare_android")


if __name__ == "__main__":
    main()
