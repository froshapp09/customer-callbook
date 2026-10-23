#!/usr/bin/env python3
"""Copy MainActivity.kt (all classes) + widget resources + force compileSdk 35."""
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]
TOOLING = Path(__file__).resolve().parent
APP = ROOT / "android" / "app"
RES = APP / "src" / "main" / "res"
KT = APP / "src" / "main" / "kotlin" / "ir" / "apadanasleep" / "customer_callbook"
MANIFEST = APP / "src" / "main" / "AndroidManifest.xml"

WIDGET_RECEIVER = '''
        <receiver
            android:name=".DaftarcheWidgetProvider"
            android:exported="true"
            android:label="@string/widget_name">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/daftarche_widget_info"/>
        </receiver>
'''


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
        t = re.sub(r"targetSdk(?:Version)?\s*=\s*[^\n]+", "targetSdk = 35", t)
        if "compileSdk" not in t and "android {" in t:
            t = t.replace("android {", "android {\n    compileSdk = 35", 1)
        f.write_text(t, encoding="utf-8")
        print("sdk", f)


def install_widget_res() -> bool:
    pairs = [
        ("layout", "daftarche_widget.xml"),
        ("xml", "daftarche_widget_info.xml"),
        ("drawable", "widget_bg.xml"),
        ("drawable", "widget_badge.xml"),
        ("values", "widget_strings.xml"),
    ]
    ok = True
    for sub, name in pairs:
        src = TOOLING / "res" / sub / name
        if not src.exists():
            print("MISSING", src)
            ok = False
            continue
        dst = RES / sub / name
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        print("res", dst)
    return ok


def main() -> None:
    if not APP.exists():
        raise SystemExit("android/app missing")
    KT.mkdir(parents=True, exist_ok=True)

    src = TOOLING / "MainActivity.kt"
    text = src.read_text(encoding="utf-8")
    for cls in (
        "MainActivity",
        "CallMonitorService",
        "CallOverlayService",
        "CallAlertActivity",
        "PhoneStateReceiver",
        "BootReceiver",
        "DaftarcheWidgetProvider",
    ):
        if f"class {cls}" not in text:
            raise SystemExit(f"class {cls} missing from MainActivity.kt")
    shutil.copy2(src, KT / "MainActivity.kt")
    print("MainActivity.kt OK")

    for name in (
        "CallMonitorService.kt",
        "CallOverlayService.kt",
        "CallAlertActivity.kt",
        "PhoneStateReceiver.kt",
        "BootReceiver.kt",
        "DaftarcheWidgetProvider.kt",
    ):
        stale = KT / name
        if stale.exists():
            stale.unlink()

    widget_ok = install_widget_res()

    shutil.copy2(TOOLING / "AndroidManifest.xml", MANIFEST)
    man = MANIFEST.read_text(encoding="utf-8")
    # strip any old widget
    man = re.sub(
        r"\s*<receiver[\s\S]*?DaftarcheWidgetProvider[\s\S]*?</receiver>\s*",
        "\n",
        man,
    )
    if widget_ok:
        # ensure string resources merged: widget_strings has widget_name
        if "</application>" in man:
            man = man.replace("</application>", WIDGET_RECEIVER + "\n    </application>", 1)
        else:
            raise SystemExit("no application end")
        print("widget receiver registered")
    else:
        print("widget SKIPPED (resources missing)")

    MANIFEST.write_text(man, encoding="utf-8")
    if "daftarche_widget_info" in man and not (RES / "xml" / "daftarche_widget_info.xml").exists():
        raise SystemExit("manifest refs widget but xml missing")
    for name in ("PhoneStateReceiver", "CallMonitorService", "CallOverlayService"):
        if name not in man:
            raise SystemExit(f"{name} missing from manifest")
    print("manifest OK")
    patch_sdk()
    print("SUCCESS prepare_android")


if __name__ == "__main__":
    main()
