# Max V1 on Apple devices

The Max iOS target keeps the current chat and access flow. Wide windows place the same live chat beside **Your Space → Thoughts** based on available width. Narrow windows open Thoughts from the chat's plus menu. The MaxWatch and MaxMac schemes are native companions for thought capture and playback. They run without an iPhone nearby and use iCloud to share thoughts after opt-in. They do not include the managed chat or the V1 subscription checkout.

## Signing and iCloud

- Enable CloudKit on the iOS, Mac and independent Watch App IDs in the same developer team. Associate all three with `iCloud.com.gindausd.max` and refresh signing profiles. Use signed builds for iCloud and microphone testing.
- In the CloudKit development environment, create records through a signed build. Promote the schema before distributing TestFlight builds. The private database uses `MaxThought` with a Bytes field named `payload`, and `MaxThoughtAccount` with a String field named `scope`. Enable querying all `MaxThought` records by adding a Queryable index on the system record name.
- On iPhone/iPad, cross-device sync is available for a signed-in Max account. The first synced Max account links the private iCloud inbox. The companions use the Apple Account on the device. Enable **Sync with iCloud** in each app. Offline recordings remain on their original device, and a fresh sync runs when the app next becomes active.
- Keep this branch out of production until the account deletion policy covers the private iCloud thought records and all companion installations. A user can remove Max's iCloud data through their Apple Account settings. The existing Max account deletion endpoint does not remove this independent iCloud data.

## Device acceptance

Use Xcode 27.1 or newer for the full iPhone Duo display and the Duo simulator in Device Hub. The existing Xcode 26 GitHub workflow checks compatibility with the older SDK. It cannot validate Duo screen transitions.

1. iPhone Duo: start typing in chat on the outer screen. Open, narrow in multitasking, and fold back. The same chat draft must remain. Check chat, text scaling, VoiceOver, microphone and demo badge on both displays.
2. Watch: add the **Save a thought** complication to a supported watch face. Tap it and verify it opens the editor, then tap **Record thought**. Repeat with the phone disconnected. Record and save a thought, quit, reopen, and replay. Reconnect, sync, and verify the same thought on iPhone, iPad and Mac. Repeated sync must not create duplicates. Verify that a second Max account on iPhone cannot load the linked iCloud inbox.
3. iPhone/iPad: allow alarms, schedule a near-term alarm from a saved thought, and confirm it rings with Max backgrounded. Reopen the same thought and verify **Manage alarm** can cancel it. Repeat for reminders and verify sign-out cancels alerts from the former account. Repeat with permission denied and verify the UI reports the error. A regular reminder is a local notification. Mac and Watch companions currently support local reminders rather than scheduling iPhone alarms remotely.
4. HomePod: with Max installed and access configured on a companion iPhone/iPad, try the **Save a thought** shortcut, answer the prompt, and look for the result in Thoughts. Check the locked-device behavior and any authentication handoff. HomePod does not run a separately installed Max app. This shortcut captures text and does not schedule HomePod alarms.
