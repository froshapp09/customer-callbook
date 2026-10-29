#!/usr/bin/env python3
"""Force release signing with tooling/release.jks — never leave debug signing."""
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]
TOOLING = Path(__file__).resolve().parent
APP = ROOT / "android" / "app"
JKS = TOOLING / "release.jks"

KEYSTORE_BLOCK = """
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file("app/key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
"""

SIGNING_INSIDE_ANDROID = """
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile rootProject.file("app/release.jks")
            storePassword keystoreProperties['storePassword']
        }
    }
"""

BUILD_TYPES = """buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled false
            shrinkResources false
            debuggable false
        }
        debug {
            signingConfig signingConfigs.release
            debuggable false
        }
    }"""


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
        raise SystemExit("android/app/build.gradle missing — run flutter create first")

    t = gradle.read_text(encoding="utf-8")

    # Remove any previous keystore injection (anywhere)
    t = re.sub(
        r"\ndef keystoreProperties = new Properties\(\)\n"
        r"def keystorePropertiesFile = [^\n]+\n"
        r"if \(keystorePropertiesFile\.exists\(\)\) \{\n"
        r"    keystoreProperties\.load\([^\)]+\)\n"
        r"\}\n?",
        "\n",
        t,
    )
    # Also remove broken prepend at very start
    t = re.sub(
        r"^def keystoreProperties = new Properties\(\)\n"
        r"def keystorePropertiesFile = [^\n]+\n"
        r"if \(keystorePropertiesFile\.exists\(\)\) \{\n"
        r"    keystoreProperties\.load\([^\)]+\)\n"
        r"\}\n+",
        "",
        t,
    )

    # Insert AFTER plugins {} block only
    if "def keystoreProperties" not in t:
        m = re.search(r"plugins\s*\{[^}]*\}\s*", t)
        if m:
            at = m.end()
            t = t[:at] + "\n" + KEYSTORE_BLOCK + "\n" + t[at:]
        else:
            t = KEYSTORE_BLOCK + "\n" + t

    if "signingConfigs" not in t:
        t = re.sub(r"android\s*\{", "android {" + SIGNING_INSIDE_ANDROID, t, count=1)

    if re.search(r"buildTypes\s*\{", t):
        t = re.sub(
            r"buildTypes\s*\{(?:[^{}]|\{(?:[^{}]|\{[^{}]*\})*\})*\}",
            BUILD_TYPES,
            t,
            count=1,
        )

    t = re.sub(r"compileSdk\s*=\s*\S+", "compileSdk = 35", t)
    t = re.sub(r"targetSdk\s*=\s*\S+", "targetSdk = 35", t)
    t = t.replace("compileSdk = flutter.compileSdkVersion", "compileSdk = 35")
    t = t.replace("targetSdk = flutter.targetSdkVersion", "targetSdk = 35")
    t = t.replace("signingConfigs.debug", "signingConfigs.release")

    gradle.write_text(t, encoding="utf-8")
    final = gradle.read_text(encoding="utf-8")
    if "signingConfigs.release" not in final:
        raise SystemExit("inject_signing failed: no signingConfigs.release")
    p = final.find("plugins {")
    k = final.find("def keystoreProperties")
    if p != -1 and k != -1 and k < p:
        raise SystemExit("inject_signing failed: keystore still before plugins {}")
    print("inject_signing OK")


if __name__ == "__main__":
    main()
