# Max interface — 17 October 2026

Max uses a cool white/glacier-blue palette, restrained typography and rounded glass controls. The supplied recordings informed spacing and material treatment. The conversation now has one continuous screen: no Home/Profile tabs, page dots or swipe navigation.

The glacier-blue orb sits on its own among the bottom controls, replacing the entire permanent “Ask Max anything” bar. It is available during conversations as well as on the empty screen. There is no pill-shaped bar behind the resting orb. The orb plays/stops Max; the separate microphone records an editable voice-to-text draft. Active orb states animate; the resting orb does not redraw continuously. The empty screen uses Max’s “Make room for what matters” typography instead of a duplicate central orb.

Type (or the plus menu) opens a text composer. Closing it preserves the draft, voice transcription opens it for review, and sending returns to the orb. Draft suggestions disappear after typing begins. History, new conversations and photos remain in the plus menu. Your day and Briefing remain beneath the dock; accessibility text sizes use More for secondary tools. The account button opens Your space, with personal photos/names, Memory, Dynamic Island and Settings available in sheets.

Light/dark appearance, reduced motion, reduced transparency and older-iOS glass fallbacks remain supported. Screenshot fixtures cover the dock on empty/conversation screens, compact and large-text layouts, dark appearance, voice capture/draft review and the account sheet using isolated sample data. System accessibility toggles still need manual acceptance; capture fixtures do not override read-only environment values.

The change is confined to presentation and captures. Physical microphone, haptic and Dynamic Island behavior, real sign-in, paid subscriptions and live AI access are not established by simulator screenshots.


## Entry screens

Welcome, Login, Sign Up and Try Demo share the glacier-blue orb, rounded editorial typography and frosted cards. The Login/Sign Up slider remains exclusive to authentication. Apple buttons adapt to appearance. The demo introduces its seven-day duration before starting, and keeps name/voice personalisation optional rather than asking for unused gender data.

Conversation styling stays as it was before the entry redesign. The floating blue orb and the removal of the permanent input bar and Home/Profile switcher remain in place.


## Supplied Max logo

The supplied black mark is Max’s brand logo. Its ring, left curve and detached lower-right curve are preserved by tracing the original reference into the shared SwiftUI shape. Even-odd fill preserves the ring opening; the mark scales and tints without a white image rectangle.

The native app icon uses a near-white background and black mark. Launch assets adapt to light/dark appearance. The entry and conversation headers pair the mark with Max’s name; existing assistant, profile and subscription logo placements use the updated shared component, as do widget identity labels. The orb and all voice actions remain unchanged.

This update has been checked as source and rendered artwork. An Xcode build and simulator/device acceptance have not been run for this source snapshot. Earlier Android and Expo prototypes are not updated by this native iPhone branding change.
