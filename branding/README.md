# Max brand artwork

The owner approved the glacier-blue glass logo on 28 October 2026. Its ring opening and detached lower-right curve are intentional.

- `Max_Logo_Glacier.png`: transparent glass-blue master used inside the native iPhone app.
- `Max_Logo_Profile.png`: square, transparent export with extra space for a circular social profile crop.
- `Max_App_Icon.png`: opaque 1024 × 1024 export for the iPhone Home Screen icon. iOS supplies its rounded mask.

`ios-swift/Sources/SharedBrand/BrandAssets.xcassets` contains the in-app artwork. The app, widget and Live Activity targets all include this catalog and the shared `MaxLogoView`; render it in original colors rather than applying a monochrome tint. The launch storyboard references this same asset.

The launch screen and entry screens place “Max” below the large mark. The real session-restoration view uses this same brand treatment without an artificial splash delay. A root-scoped geometry namespace connects the active entry logo to the compact Home header when the existing access gate allows entry. Failed or cancelled authentication and unavailable subscriptions do not open Home. The demo remains in the same view hierarchy so its logo can make the same transition. Only the selected login/signup page participates in the shared geometry; Reduce Motion uses a short fade instead of the travelling animation.

The introductory tour is optional from the welcome screen rather than covering Home immediately after successful entry. The voice-control orb remains in the assistant interface.

The original black/white references, SVG and path data remain archival sources. `import_logo.py` regenerates only those monochrome exports. It deliberately does not overwrite the approved blue artwork, native view or app icon.

Asset installation and an unsigned build do not establish a signed iPhone install, TestFlight availability or physical-device behavior.

## Compact Home identity and Shortcuts

The Home header uses a 44pt-wide logo; the separate voice orb is 64pt. Entry and launch artwork stay large.

Your space → Dynamic Island explains the Shortcuts connection and opens Max's own App Shortcuts page using Apple's `ShortcutsLink`. `Start Max Island` opens Max and queues a Live Activity request until Home is both accessible and active. It does not request microphone capture. `Activate Max` is the separate direct-voice shortcut. Both requests are consumed once, survive initial login/session restoration, and are cleared on sign-out or an account switch. The access predicate, trial duration, backend and provider settings are unchanged.

Disabled/failed Live Activity requests from the island shortcut show an actionable message. Reopening an existing active/stale activity preserves its conversation phase instead of resetting it to Ready. Ended/dismissed activities are not reused. Live Activities remain temporary and system managed; no always-on background microphone or indefinite island presence is promised. iPhones without Dynamic Island use the Lock Screen presentation.

Acceptance on a signed physical iPhone: run each shortcut with Max terminated and already open; complete login/demo if necessary; confirm only Activate Max requests microphone access; confirm one Live Activity and correct phase after repeated runs; verify disabled Live Activities show the message; verify Talk/Briefing/Plan links, permission denial, sign-out and demo expiry. On supported hardware confirm Dynamic Island, and on other hardware confirm the Lock Screen. Simulator tests verify the request queue and buildable UI only.
