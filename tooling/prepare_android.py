#!/usr/bin/env python3
"""Write widget resources and force compileSdk 35. No YAML heredocs."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / "android"
APP = ANDROID / "app"
RES = APP / "src" / "main" / "res"
KT = APP / "src" / "main" / "kotlin" / "ir" / "apadanasleep" / "customer_callbook"

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
        android:text="no calls"
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

STRINGS = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="widget_description">Today calls</string>
    <string name="widget_name">Daftarche</string>
</resources>
"""


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    print("wrote", path, "bytes", path.stat().st_size)


def patch_sdk() -> None:
    if not ANDROID.exists():
        print("android/ missing, skip sdk patch")
        return
    for f in ANDROID.rglob("build.gradle*"):
        t = f.read_text(encoding="utf-8")
        orig = t
        t = re.sub(
            r"compileSdk(?:Version)?\s*=?\s*[^\n]+",
            "compileSdk = 35",
            t,
        )
        t = re.sub(
            r"targetSdk(?:Version)?\s*=?\s*[^\n]+",
            "targetSdk = 35",
            t,
        )
        # undo accidental replacement of unrelated lines that contained the word inside comments only if we doubled
        if t != orig:
            f.write_text(t, encoding="utf-8")
        print("sdk", f)


def main() -> None:
    write(RES / "layout" / "daftarche_widget.xml", LAYOUT)
    write(RES / "xml" / "daftarche_widget_info.xml", INFO)
    write(RES / "drawable" / "widget_bg.xml", BG)
    write(RES / "values" / "widget_strings.xml", STRINGS)
    src_kt = Path(__file__).resolve().parent / "DaftarcheWidgetProvider.kt"
    if src_kt.exists():
        KT.mkdir(parents=True, exist_ok=True)
        (KT / "DaftarcheWidgetProvider.kt").write_text(
            src_kt.read_text(encoding="utf-8"), encoding="utf-8"
        )
        print("wrote provider")
    manifest_src = Path(__file__).resolve().parent / "AndroidManifest.xml"
    manifest_dst = APP / "src" / "main" / "AndroidManifest.xml"
    if manifest_src.exists() and APP.exists():
        manifest_dst.write_text(manifest_src.read_text(encoding="utf-8"), encoding="utf-8")
        print("wrote manifest")
    patch_sdk()
    info = RES / "xml" / "daftarche_widget_info.xml"
    if not info.exists() or info.stat().st_size < 50:
        raise SystemExit("widget xml missing")
    print("SUCCESS widget resources installed", info)


if __name__ == "__main__":
    main()
