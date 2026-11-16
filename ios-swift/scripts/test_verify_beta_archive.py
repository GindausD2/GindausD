import plistlib
import tempfile
import unittest
from pathlib import Path

from verify_beta_archive import BETA_API, verify


class ArchiveVerificationTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.archive = Path(directory.name)
        self.app = self.archive / "Products/Applications/Max.app"
        self.write(self.archive / "Info.plist", {
            "ApplicationProperties": {"ApplicationPath": "Applications/Max.app", "Team": "MYTEST1234"}
        })
        self.info = {
            "CFBundleIdentifier": "com.gindausd.max",
            "CFBundleVersion": "12",
            "CFBundleShortVersionString": "1.0.0",
            "NSMicrophoneUsageDescription": "Record your thought.",
            "NSAlarmKitUsageDescription": "Schedule your alarm.",
            "MAX_API_BASE_URL": BETA_API,
        }
        self.write(self.app / "Info.plist", self.info)
        self.add_extension("MaxLiveActivity", "com.gindausd.max.liveactivity")
        self.add_extension("MaxWidget", "com.gindausd.max.widget")

    @staticmethod
    def write(path, value):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(plistlib.dumps(value))

    def add_extension(self, name, bundle_id, build="12"):
        self.write(self.app / "PlugIns" / f"{name}.appex" / "Info.plist", {
            "CFBundleIdentifier": bundle_id,
            "CFBundleShortVersionString": "1.0.0",
            "CFBundleVersion": build,
        })

    def test_accepts_ios_archive_targeting_beta(self):
        verify(self.archive, "Max", "12")

    def test_rejects_production_backend(self):
        self.info["MAX_API_BASE_URL"] = BETA_API.removesuffix("-beta")
        self.write(self.app / "Info.plist", self.info)
        with self.assertRaisesRegex(ValueError, "beta API"):
            verify(self.archive, "Max", "12")

    def test_rejects_extension_build_mismatch(self):
        self.add_extension("MaxWidget", "com.gindausd.max.widget", build="11")
        with self.assertRaisesRegex(ValueError, "MaxWidget"):
            verify(self.archive, "Max", "12")

    def test_accepts_standalone_watch_and_capture_extension(self):
        self.info.update({
            "CFBundleIdentifier": "com.gindausd.max.watch",
            "WKWatchOnly": True,
            "CFBundleURLTypes": [{"CFBundleURLSchemes": ["max-watch"]}],
        })
        self.write(self.app / "Info.plist", self.info)
        self.add_extension("MaxWatchWidget", "com.gindausd.max.watch.capture")
        verify(self.archive, "MaxWatch", "12")

    def test_accepts_macos_info_inside_contents(self):
        self.info["CFBundleIdentifier"] = "com.gindausd.max.mac"
        self.write(self.app / "Contents/Info.plist", self.info)
        verify(self.archive, "MaxMac", "12")


if __name__ == "__main__":
    unittest.main()
