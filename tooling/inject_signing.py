#!/usr/bin/env python3
"""Inject release signingConfig into android/app/build.gradle using tooling keystore."""
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
        # try kts only - write a note
        if (APP / "build.gradle.kts").exists():
            raise SystemExit("build.gradle.kts not supported by inject_signing")
        raise SystemExit("android/app/build.gradle missing")

    t = gradle.read_text(encoding="utf-8")

    header = """def keystoreProperties = new Properties()
def keystorePropertiesFile = file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

"""
    if "def keystoreProperties" not in t:
        t = header + t

    if "signingConfigs {" not in t:
        t = t.replace(
            "android {",
            """android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile file(keystoreProperties['storeFile'])
            storePassword keystoreProperties['storePassword']
        }
    }
""",
            1,
        )

    # Replace entire buildTypes block to force release signing
    t2, n = re.subn(
        r"buildTypes\s*\{(?:[^{}]|\{[^{}]*\})*\}",
        """buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled false
        }
        debug {
            signingConfig signingConfigs.release
        }
    }""",
        t,
        count=1,
    )
    if n:
        t = t2
    else:
        # fallback inject
        if "signingConfig signingConfigs.release" not in t:
            t = t.replace(
                "buildTypes {",
                """buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled false
        }
""",
                1,
            )

    t = re.sub(r"compileSdk\s*=\s*\S+", "compileSdk = 35", t)
    t = re.sub(r"targetSdk\s*=\s*\S+", "targetSdk = 35", t)
    t = t.replace("compileSdk = flutter.compileSdkVersion", "compileSdk = 35")
    t = t.replace("targetSdk = flutter.targetSdkVersion", "targetSdk = 35")

    gradle.write_text(t, encoding="utf-8")
    if "signingConfigs.release" not in t and "signingConfig signingConfigs.release" not in gradle.read_text(encoding="utf-8"):
        raise SystemExit("failed to inject signingConfigs.release")
    print("inject_signing OK", gradle)


if __name__ == "__main__":
    main()
