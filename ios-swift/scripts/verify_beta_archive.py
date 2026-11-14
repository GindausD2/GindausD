"""Check archive metadata before handing a build to TestFlight."""
import argparse
import plistlib
from pathlib import Path

APP_IDS = {
    "Max": "com.gindausd.max",
    "MaxWatch": "com.gindausd.max.watch",
    "MaxMac": "com.gindausd.max.mac",
}
BETA_API = "https://omcboajliacdnhrroijb.supabase.co/functions/v1/max-api-beta"
SUBTARGETS = {
    "Max": {
        "MaxLiveActivity": "com.gindausd.max.liveactivity",
        "MaxWidget": "com.gindausd.max.widget",
    },
    "MaxWatch": {"MaxWatchWidget": "com.gindausd.max.watch.capture"},
    "MaxMac": {},
}


def read_plist(path):
    with path.open("rb") as stream:
        return plistlib.load(stream)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify(archive, scheme, build_number):
    archive_info = read_plist(archive / "Info.plist")
    properties = archive_info.get("ApplicationProperties", {})
    relative = properties.get("ApplicationPath")
    require(relative, "Archive does not contain a distributable app.")
    require(properties.get("Team"), "Archive metadata does not identify a signing team.")
    app = archive / "Products" / relative
    mac = scheme == "MaxMac"
    info = read_plist(app / ("Contents/Info.plist" if mac else "Info.plist"))
    require(info.get("CFBundleIdentifier") == APP_IDS[scheme], "Unexpected app bundle ID.")
    require(info.get("CFBundleVersion") == build_number, "Archive build number does not match MAX_BUILD_NUMBER.")
    require(bool(info.get("NSMicrophoneUsageDescription")), "Missing microphone purpose string.")

    if scheme == "Max":
        require(info.get("MAX_API_BASE_URL") == BETA_API, "iPhone/iPad archive must use the Max beta API.")
        require(bool(info.get("NSAlarmKitUsageDescription")), "Missing alarm purpose string.")
    if scheme == "MaxWatch":
        require(info.get("WKWatchOnly") is True, "MaxWatch must be a standalone watchOS app.")
        schemes = {scheme for item in info.get("CFBundleURLTypes", []) for scheme in item.get("CFBundleURLSchemes", [])}
        require("max-watch" in schemes, "Missing the Watch capture URL scheme.")

    for name, bundle_id in SUBTARGETS[scheme].items():
        extension = read_plist(app / "PlugIns" / f"{name}.appex" / "Info.plist")
        require(extension.get("CFBundleIdentifier") == bundle_id, f"Wrong bundle ID for {name}.")
        require(extension.get("CFBundleVersion") == build_number, f"Build number mismatch in {name}.")
        require(extension.get("CFBundleShortVersionString") == info.get("CFBundleShortVersionString"),
                f"Version mismatch in {name}.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("scheme", choices=APP_IDS)
    parser.add_argument("build_number")
    args = parser.parse_args()
    try:
        verify(args.archive, args.scheme, args.build_number)
    except (OSError, ValueError, plistlib.InvalidFileException) as error:
        parser.exit(1, f"Archive check failed: {error}\n")
