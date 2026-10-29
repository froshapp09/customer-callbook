#!/usr/bin/env python3
"""Rewrite android/app/build.gradle signing so release keystore is always used."""
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]
TOOLING = Path(__file__).resolve().parent
APP = ROOT / "android" / "app"
JKS = TOOLING / "release.jks"


def main() -> None:
    if not JKS.exists():
        raise SystemExit("missing tooling/release.jks")
    APP.mkdir(parents=True, exist_ok=True)
    shutil.copy2(JKS, APP / "release.jks")
    (APP / "key.properties").write_text(
        "storePassword=callbook2026\n"
        "keyPassword=callbook2026\n"
        "keyAlias=customer_callbook\n"
        "storeFile=release.jks\n",
        encoding="utf-8",
    )

    gradle = APP / "build.gradle"
    if not gradle.exists():
        raise SystemExit("android/app/build.gradle missing")

    t = gradle.read_text(encoding="utf-8")

    # Strip previous injections
    t = re.sub(
        r"\ndef keystoreProperties[\s\S]*?keystoreProperties\.load\([^\n]+\)\n\}\n*",
        "\n",
        t,
    )
    t = re.sub(r"signingConfigs\s*\{(?:[^{}]|\{[^{}]*\})*\}", "", t)

    # Extract plugins block if present
    plugins_m = re.search(r"plugins\s*\{[^}]*\}", t)
    plugins = plugins_m.group(0) if plugins_m else (
        'plugins {\n'
        '    id "com.android.application"\n'
        '    id "kotlin-android"\n'
        '    id "dev.flutter.flutter-gradle-plugin"\n'
        '}'
    )

    # applicationId / namespace from existing file
    app_id = "ir.apadanasleep.customer_callbook"
    m = re.search(r'applicationId\s*=\s*"([^"]+)"', t)
    if m:
        app_id = m.group(1)
    ns = app_id
    m = re.search(r'namespace\s*=\s*"([^"]+)"', t)
    if m:
        ns = m.group(1)

    # Keep flutter / kotlin version lines if any after plugins
    extra = ""
    for pat in [
        r'android\s*\{[\s\S]*',  # drop - we rewrite android block
    ]:
        pass

    # Full safe file — plugins first, then keystore, then android
    new = f'''{plugins}

def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file("app/key.properties")
if (keystorePropertiesFile.exists()) {{
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}}

android {{
    namespace = "{ns}"
    compileSdk = 35

    compileOptions {{
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }}

    kotlinOptions {{
        jvmTarget = JavaVersion.VERSION_1_8
    }}

    defaultConfig {{
        applicationId = "{app_id}"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }}

    signingConfigs {{
        release {{
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile rootProject.file("app/release.jks")
            storePassword keystoreProperties['storePassword']
        }}
    }}

    buildTypes {{
        release {{
            signingConfig signingConfigs.release
            minifyEnabled false
            shrinkResources false
            debuggable false
        }}
        debug {{
            signingConfig signingConfigs.release
            debuggable false
        }}
    }}
}}

flutter {{
    source = "../.."
}}
'''

    # If original had dependencies block, append it
    dep = re.search(r"dependencies\s*\{[\s\S]*\}\s*$", t)
    if dep:
        new += "\n" + dep.group(0) + "\n"

    gradle.write_text(new, encoding="utf-8")
    print("inject_signing OK (full rewrite)")
    print(new[:600])


if __name__ == "__main__":
    main()
