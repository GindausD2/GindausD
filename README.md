# Max — AI Personal Assistant

A mobile-first AI personal assistant powered by Claude, built with React Native + Expo.

## Features

- **Streaming chat** — Responses appear word-by-word in real time
- **Voice input** — Tap the mic, speak, and Max transcribes your words via Claude's audio API
- **Voice output** — Max reads responses aloud using native text-to-speech
- **Tool use** — Max can save notes, set reminders, remember facts, and check the time
- **Persistent memory** — Notes and facts survive across sessions (stored locally with AsyncStorage)
- **Reminders** — Native push notifications scheduled through the conversation
- **Quick actions** — One-tap prompts for common tasks
- **Beautiful dark UI** — Deep purple theme, smooth animations, markdown rendering

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | React Native + Expo SDK 51 |
| AI Model | Claude claude-sonnet-4-6 (streaming + tool use) |
| Voice Output | expo-speech |
| Voice Input | expo-av + Claude audio transcription |
| Storage | AsyncStorage |
| Notifications | expo-notifications |
| Navigation | expo-router |

## Getting Started

### Prerequisites

- Node.js 18+
- Expo CLI (`npm install -g expo-cli`)
- Expo Go app on your phone, or an iOS/Android simulator
- An [Anthropic API key](https://console.anthropic.com/)

### Setup

```bash
# Clone and install
git clone <repo>
cd max-ai-assistant
npm install

# Start the dev server
npx expo start
```

Scan the QR code with Expo Go (Android) or the Camera app (iOS).

### Adding your API key

Open Max → tap the gear icon → paste your Anthropic API key → tap **Save**.

Your key is stored locally on-device and never leaves your phone.

## Project Structure

```
├── app/
│   ├── _layout.tsx       # Root layout + notification setup
│   ├── index.tsx         # Main chat screen
│   └── settings.tsx      # Settings (API key, voice, data)
├── components/
│   ├── ChatBubble.tsx    # Message bubbles with markdown rendering
│   ├── Header.tsx        # Top bar with avatar, actions
│   ├── InputBar.tsx      # Text input + voice recording UI
│   ├── QuickActions.tsx  # Shortcut chips for common prompts
│   └── TypingIndicator.tsx  # Animated dots while Max thinks
├── hooks/
│   ├── useChat.ts        # Chat state, streaming, tool handling
│   ├── useSettings.ts    # Settings load/save
│   ├── useVoice.ts       # TTS (speak/stop)
│   └── useVoiceRecorder.ts  # STT recording + transcription
├── services/
│   ├── claude.ts         # Anthropic SDK, streaming, agentic loop
│   ├── storage.ts        # AsyncStorage (messages, notes, memory)
│   ├── tools.ts          # Tool definitions + handlers
│   └── whisper.ts        # Audio recording + transcription
├── constants/
│   ├── colors.ts         # Dark theme palette
│   └── prompts.ts        # System prompt + welcome message
└── types/
    └── index.ts          # TypeScript interfaces
```

## Tools Max Can Use

| Tool | What it does |
|------|-------------|
| `save_note` | Save a note locally |
| `get_notes` | Retrieve all notes |
| `delete_note` | Delete a specific note |
| `remember_fact` | Store a user fact (name, preferences, etc.) |
| `recall_facts` | Retrieve stored facts |
| `get_datetime` | Get current date + time + timezone |
| `schedule_reminder` | Schedule a push notification |
| `get_reminders` | List upcoming reminders |

## Example Conversations

> **You:** "Remember that my partner's birthday is May 15th"
> **Max:** Uses `remember_fact` → "Got it! I've saved that — I won't forget."

> **You:** "Set a reminder in 30 minutes to drink water"
> **Max:** Uses `schedule_reminder` → Schedules a native notification

> **You:** "Save a note about my project ideas"
> **Max:** Uses `save_note` → "Note saved! What else can I help with?"
