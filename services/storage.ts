import AsyncStorage from '@react-native-async-storage/async-storage';
import { Message, Note, UserMemory, Reminder, AssistantSettings } from '@/types';

const KEYS = {
  MESSAGES: 'aria:messages',
  NOTES: 'aria:notes',
  MEMORIES: 'aria:memories',
  REMINDERS: 'aria:reminders',
  SETTINGS: 'aria:settings',
} as const;

// ─── Messages ────────────────────────────────────────────────────────────────

export async function loadMessages(): Promise<Message[]> {
  try {
    const raw = await AsyncStorage.getItem(KEYS.MESSAGES);
    return raw ? JSON.parse(raw) : [];
  } catch {
    return [];
  }
}

export async function saveMessages(messages: Message[]): Promise<void> {
  try {
    // Keep only the last 200 messages to avoid storage bloat
    const trimmed = messages.slice(-200);
    await AsyncStorage.setItem(KEYS.MESSAGES, JSON.stringify(trimmed));
  } catch (e) {
    console.error('[storage] Failed to save messages:', e);
  }
}

export async function clearMessages(): Promise<void> {
  await AsyncStorage.removeItem(KEYS.MESSAGES);
}

// ─── Notes ───────────────────────────────────────────────────────────────────

export async function loadNotes(): Promise<Note[]> {
  try {
    const raw = await AsyncStorage.getItem(KEYS.NOTES);
    return raw ? JSON.parse(raw) : [];
  } catch {
    return [];
  }
}

export async function saveNote(note: Omit<Note, 'id' | 'createdAt' | 'updatedAt'>): Promise<Note> {
  const notes = await loadNotes();
  const newNote: Note = {
    id: `note_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
    ...note,
    createdAt: Date.now(),
    updatedAt: Date.now(),
  };
  notes.push(newNote);
  await AsyncStorage.setItem(KEYS.NOTES, JSON.stringify(notes));
  return newNote;
}

export async function deleteNote(id: string): Promise<boolean> {
  const notes = await loadNotes();
  const filtered = notes.filter((n) => n.id !== id);
  if (filtered.length === notes.length) return false;
  await AsyncStorage.setItem(KEYS.NOTES, JSON.stringify(filtered));
  return true;
}

// ─── User Memory ─────────────────────────────────────────────────────────────

export async function loadMemories(): Promise<UserMemory[]> {
  try {
    const raw = await AsyncStorage.getItem(KEYS.MEMORIES);
    return raw ? JSON.parse(raw) : [];
  } catch {
    return [];
  }
}

export async function rememberFact(key: string, value: string): Promise<void> {
  const memories = await loadMemories();
  const idx = memories.findIndex((m) => m.key.toLowerCase() === key.toLowerCase());
  const entry: UserMemory = { key, value, updatedAt: Date.now() };
  if (idx >= 0) {
    memories[idx] = entry;
  } else {
    memories.push(entry);
  }
  await AsyncStorage.setItem(KEYS.MEMORIES, JSON.stringify(memories));
}

export async function recallFacts(): Promise<UserMemory[]> {
  return loadMemories();
}

// ─── Reminders ───────────────────────────────────────────────────────────────

export async function loadReminders(): Promise<Reminder[]> {
  try {
    const raw = await AsyncStorage.getItem(KEYS.REMINDERS);
    return raw ? JSON.parse(raw) : [];
  } catch {
    return [];
  }
}

export async function saveReminder(reminder: Reminder): Promise<void> {
  const reminders = await loadReminders();
  reminders.push(reminder);
  await AsyncStorage.setItem(KEYS.REMINDERS, JSON.stringify(reminders));
}

export async function removeReminder(id: string): Promise<void> {
  const reminders = await loadReminders();
  const filtered = reminders.filter((r) => r.id !== id);
  await AsyncStorage.setItem(KEYS.REMINDERS, JSON.stringify(filtered));
}

// ─── Settings ─────────────────────────────────────────────────────────────────

const DEFAULT_SETTINGS: AssistantSettings = {
  apiKey: '',
  assistantName: 'Aria',
  voiceEnabled: true,
  voiceSpeed: 1.0,
  voicePitch: 1.1,
  userName: '',
  theme: 'dark',
};

export async function loadSettings(): Promise<AssistantSettings> {
  try {
    const raw = await AsyncStorage.getItem(KEYS.SETTINGS);
    return raw ? { ...DEFAULT_SETTINGS, ...JSON.parse(raw) } : DEFAULT_SETTINGS;
  } catch {
    return DEFAULT_SETTINGS;
  }
}

export async function saveSettings(settings: Partial<AssistantSettings>): Promise<AssistantSettings> {
  const current = await loadSettings();
  const updated = { ...current, ...settings };
  await AsyncStorage.setItem(KEYS.SETTINGS, JSON.stringify(updated));
  return updated;
}
