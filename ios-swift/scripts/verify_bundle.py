"""Validate the installed app metadata, not just the source plist."""
import plistlib
import sys
from pathlib import Path

for name in sys.argv[1:]:
    app = Path(name)
    with (app / "Info.plist").open("rb") as f:
        info = plistlib.load(f)
    for key in ("NSMicrophoneUsageDescription", "NSSpeechRecognitionUsageDescription", "NSLocationWhenInUseUsageDescription", "NSCalendarsFullAccessUsageDescription"):
        assert isinstance(info.get(key), str) and info[key].strip(), f"Missing {key} in {app}"
    assert info.get("NSSupportsLiveActivities") is True, f"Live Activities disabled in {app}"
    schemes = {s for item in info.get("CFBundleURLTypes", []) for s in item.get("CFBundleURLSchemes", [])}
    assert {"maxapp", "com.gindausd.max"} <= schemes, f"Missing deep-link/OAuth schemes in {app}"
    assert "com.max.ai.liveactivity.refresh" in info.get("BGTaskSchedulerPermittedIdentifiers", []), f"Missing background task registration in {app}"
    assert info.get("UILaunchStoryboardName") == "LaunchScreen", f"Missing launch configuration in {app}"
    assert list(app.glob("**/LaunchScreen.storyboardc")), f"Launch storyboard not packaged in {app}"
    for key in ("MAX_API_BASE_URL", "SUPABASE_URL", "SUPABASE_ANON_KEY"):
        assert isinstance(info.get(key), str) and info[key] and "$(" not in info[key], f"Unexpanded public build setting {key} in {app}"
    assert info.get("CFBundleIdentifier") == "com.gindausd.max"
    for target in ("MaxLiveActivity", "MaxWidget"):
        extension = app / "PlugIns" / f"{target}.appex" / "Info.plist"
        with extension.open("rb") as f:
            metadata = plistlib.load(f)
        assert metadata.get("NSExtension", {}).get("NSExtensionPointIdentifier") == "com.apple.widgetkit-extension", f"Invalid embedded {target}"
    print(f"PASS: {app.name} privacy descriptions, Live Activities, URL schemes, background registration, launch screen, expanded public settings, and both embedded extensions")
