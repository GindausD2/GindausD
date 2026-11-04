# Keep me on track

This follow-up builds on PR #4. It adds to the native iPhone implementation; it is source for review, not a signed app or deployed backend.

## Resulting behavior

1. Spoken or typed AI reminder requests show a native review sheet before scheduling. The sheet displays the title, exact local date/time and time-zone identifier, or the named arrival/context trigger. Confirm schedules it; Cancel or dismiss makes no scheduling change. Initial invalid or ambiguous time requests still require clarification. Cancellation, stopping the conversation and account changes invalidate outstanding approval. Manual reminder forms retain their explicit Save action.
2. Your day opens on Today. It shows the next timed calendar appointment today, up to three user-entered daily priorities, and unfinished reminders including overdue ones. Calendar access is requested only through Connect calendar. Denied/unavailable access is distinguished from an empty calendar. Completing a reminder persists its completion and removes pending/delivered notifications. Reschedule uses a reviewed future time and replaces the notification under the same ID after scheduling succeeds; converting an arrival/context reminder to a time reminder is disclosed. Older saved reminders decode as unfinished.
3. Settings → Voice vocabulary lets the user add/remove up to 25 names or phrases, each up to 64 characters. Entries are scoped to the current account and used as Apple recognition context and literal OpenAI transcription keywords. They are not text replacement rules. The UI discloses that they accompany future recordings. The backend validates the optional base64 vocabulary header before quota/provider access. The verbatim prompt and returned original-language text are unchanged. Accuracy and pronunciation coverage must still be measured on real audio.
4. Memory retains existing edit/forget controls and adds Use saved memory. Turning it off prevents saved facts/cards from entering new model requests and prevents the remember/recall fact tools from writing or exposing facts. Existing memories remain available to edit/delete or explicitly add manually. Pausing does not erase conversation history or remove details already present in that history. Turning memory back on restores use of saved details.

Priorities, completion state and vocabulary are account-local. Priority lists use the local calendar date and retain at most 93 entries across days. There is no background behavioral monitoring, automatic social posting or inferred priority creation. Notification delivery remains controlled by iOS and requires authorization. This change does not add notification action buttons; completion and rescheduling are available inside Today.

## Validation

57 Node backend tests pass locally, including vocabulary passthrough and rejection before quota/provider calls. Native tests were added for pre-save reminder approval/cancellation, stale approval/account switching, daily priority limits/isolation, memory pause, vocabulary validation/isolation, rescheduling failure/success and completion. Xcode and Swift are unavailable locally; use this follow-up's own CI for native build/test evidence. Do not reuse PR #3 or #4 build results as proof of these additions.

## Physical acceptance, all NOT RUN

| Flow | Pass criteria |
| --- | --- |
| Voice → review → reminder | After a real spoken request, Max shows the intended title/date/time/time zone. No notification exists until Confirm. Confirm saves exactly one reminder and produces the expected notification. Cancel, swipe-dismiss, stop or sign-out saves none. Ambiguous input prompts clarification. |
| Today | An authorized calendar with a known timed event shows the correct next event. Denied permission shows an access message. Empty calendar shows no timed appointments. Three priorities persist across relaunch, completion and account changes remain isolated, and a new local day starts a separate list. |
| Unfinished reminders | A delivered or overdue unfinished reminder stays visible. Complete survives relaunch and removes notification requests. Reschedule keeps one reminder with the same ID at the new time. Denied permission or scheduling failure does not alter the saved date. |
| Personal vocabulary | Add names in account A, dictate a prepared natural-accent sample, and record actual transcription accuracy. Delete hints and repeat. Account B cannot view or send A's hints. An unseen language/accent remains unverified. |
| Memory controls | Turn memory off, start a new conversation and inspect the outgoing remembered context/tool behavior: no saved facts/cards are exposed, and new fact-saving requests are refused. Edit/forget existing memories, enable memory and verify deleted content does not return. History remains separately managed. |

Record app/backend commit, iPhone model/iOS, account state, expected/actual result and redacted screenshots or request evidence. Signed TestFlight delivery, real provider accuracy, notification permissions/delivery, Shortcuts, Live Activity behavior and Dynamic Island appearance remain unverified until executed on physical devices.
