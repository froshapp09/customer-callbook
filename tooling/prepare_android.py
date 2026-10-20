#!/usr/bin/env python3
"""Force compileSdk 35 + write home-screen widget resources + register receiver."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / "android"
APP = ANDROID / "app"
RES = APP / "src" / "main" / "res"
KT = APP / "src" / "main" / "kotlin" / "ir" / "apadanasleep" / "customer_callbook"
MANIFEST = APP / "src" / "main" / "AndroidManifest.xml"
TOOLING = Path(__file__).resolve().parent

LAYOUT = """<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/widget_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="14dp"
    android:background="@drawable/widget_bg">
    <TextView
        android:id="@+id/widget_count"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:text="0"
        android:textColor="#6C63FF"
        android:textSize="18sp"
        android:textStyle="bold" />
    <TextView
        android:id="@+id/widget_line1"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="8dp"
        android:text="-"
        android:textColor="#1A1730"
        android:textSize="13sp"
        android:maxLines="1"
        android:ellipsize="end" />
    <TextView
        android:id="@+id/widget_line2"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="4dp"
        android:text=""
        android:textColor="#5C5878"
        android:textSize="12sp"
        android:maxLines="1"
        android:ellipsize="end" />
    <TextView
        android:id="@+id/widget_line3"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="4dp"
        android:text=""
        android:textColor="#5C5878"
        android:textSize="12sp"
        android:maxLines="1"
        android:ellipsize="end" />
</LinearLayout>
"""

INFO = """<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="180dp"
    android:minHeight="110dp"
    android:updatePeriodMillis="1800000"
    android:initialLayout="@layout/daftarche_widget"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen" />
"""

BG = """<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <solid android:color="#F5F4FF" />
    <corners android:radius="20dp" />
</shape>
"""


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    print("wrote", path)


def patch_sdk() -> None:
    if not ANDROID.exists():
        return
    for f in ANDROID.rglob("build.gradle*"):
        t = f.read_text(encoding="utf-8")
        orig = t
        t = re.sub(r"compileSdk(?:Version)?\s*=\s*[^\n]+", "compileSdk = 35", t)
        t = re.sub(r"compileSdkVersion\s+[^\n]+", "compileSdk 35", t)
        t = re.sub(r"targetSdk(?:Version)?\s*=\s*[^\n]+", "targetSdk = 35", t)
        t = re.sub(r"targetSdkVersion\s+[^\n]+", "targetSdkVersion 35", t)
        if t != orig:
            f.write_text(t, encoding="utf-8")
        print("sdk", f)


def ensure_widget_receiver() -> None:
    if not MANIFEST.exists():
        return
    t = MANIFEST.read_text(encoding="utf-8")
    if "DaftarcheWidgetProvider" in t:
        print("receiver already in manifest")
        return
    receiver = '''
        <receiver
            android:name=".DaftarcheWidgetProvider"
            android:exported="true"
            android:label="دفترچه مشتریان">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/daftarche_widget_info" />
        </receiver>
'''
    if "</application>" in t:
        t = t.replace("</application>", receiver + "\n    </application>", 1)
        MANIFEST.write_text(t, encoding="utf-8")
        print("receiver added to manifest")
    else:
        print("WARN no application tag")


def main() -> None:
    write(RES / "layout" / "daftarche_widget.xml", LAYOUT)
    write(RES / "xml" / "daftarche_widget_info.xml", INFO)
    write(RES / "drawable" / "widget_bg.xml", BG)
    src_kt = TOOLING / "DaftarcheWidgetProvider.kt"
    if src_kt.exists():
        KT.mkdir(parents=True, exist_ok=True)
        (KT / "DaftarcheWidgetProvider.kt").write_text(
            src_kt.read_text(encoding="utf-8"), encoding="utf-8"
        )
        print("provider kotlin copied")
    # Prefer tooling manifest base (permissions) then add receiver
    tool_manifest = TOOLING / "AndroidManifest.xml"
    if tool_manifest.exists() and APP.exists():
        MANIFEST.parent.mkdir(parents=True, exist_ok=True)
        MANIFEST.write_text(tool_manifest.read_text(encoding="utf-8"), encoding="utf-8")
        print("base manifest copied")
    ensure_widget_receiver()
    # verify xml exists BEFORE leaving
    info = RES / "xml" / "daftarche_widget_info.xml"
    if not info.exists() or info.stat().st_size < 40:
        raise SystemExit("widget xml missing after write")
    if MANIFEST.exists() and "daftarche_widget_info" not in MANIFEST.read_text():
        raise SystemExit("manifest missing widget resource ref")
    patch_sdk()
    print("SUCCESS prepare_android widget+sdk")


if __name__ == "__main__":
    main()
