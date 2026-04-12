/**
 * Tool definitions and handlers for the AI assistant.
 * Each tool maps to a local operation (storage, notifications, etc.)
 */

import * as Notifications from 'expo-notifications';
import {
  saveNote,
  loadNotes,
  deleteNote,
  rememberFact,
  recallFacts,
  saveReminder,
  loadReminders,
} from './storage';
import { Note, UserMemory, Reminder } from '@/types';

// ─── Tool Definitions (sent to Claude API) ────────────────────────────────────

export const TOOL_DEFINITIONS = [
  {
    name: 'save_note',
    description: 'Save a note to the user\'s local storage. Use this when the user wants to save information, ideas, or anything worth keeping.',
    input_schema: {
      type: 'object',
      properties: {
        title: { type: 'string', description: 'Short descriptive title for the note' },
        content: { type: 'string', description: 'The full content of the note' },
      },
      required: ['title', 'content'],
    },
  },
  {
    name: 'get_notes',
    description: 'Retrieve all saved notes from the user\'s local storage.',
    input_schema: {
      type: 'object',
      properties: {},
      required: [],
    },
  },
  {
    name: 'delete_note',
    description: 'Delete a specific note by its ID.',
    input_schema: {
      type: 'object',
      properties: {
        id: { type: 'string', description: 'The ID of the note to delete' },
      },
      required: ['id'],
    },
  },
  {
    name: 'remember_fact',
    description: 'Store a fact about the user for future conversations. Use this proactively when the user shares personal information, preferences, or anything worth remembering (e.g., their name, job, hobbies, preferences).',
    input_schema: {
      type: 'object',
      properties: {
        key: { type: 'string', description: 'Category or label for the fact (e.g., "name", "job", "favorite_color")' },
        value: { type: 'string', description: 'The fact to remember' },
      },
      required: ['key', 'value'],
    },
  },
  {
    name: 'recall_facts',
    description: 'Recall all facts remembered about the user.',
    input_schema: {
      type: 'object',
      properties: {},
      required: [],
    },
  },
  {
    name: 'get_datetime',
    description: 'Get the current date and time.',
    input_schema: {
      type: 'object',
      properties: {},
      required: [],
    },
  },
  {
    name: 'schedule_reminder',
    description: 'Schedule a reminder notification for the user at a specific time.',
    input_schema: {
      type: 'object',
      properties: {
        message: { type: 'string', description: 'The reminder message to show' },
        delay_minutes: { type: 'number', description: 'How many minutes from now to show the reminder (minimum: 1)' },
      },
      required: ['message', 'delay_minutes'],
    },
  },
  {
    name: 'get_reminders',
    description: 'Get all scheduled reminders.',
    input_schema: {
      type: 'object',
      properties: {},
      required: [],
    },
  },
] as const;

// ─── Tool Handlers ─────────────────────────────────────────────────────────────

export async function executeTool(
  name: string,
  input: Record<string, unknown>
): Promise<string> {
  try {
    switch (name) {
      case 'save_note': {
        const note = await saveNote({
          title: input.title as string,
          content: input.content as string,
        });
        return JSON.stringify({ success: true, note_id: note.id, message: `Note "${note.title}" saved.` });
      }

      case 'get_notes': {
        const notes: Note[] = await loadNotes();
        if (notes.length === 0) {
          return JSON.stringify({ notes: [], message: 'No notes saved yet.' });
        }
        return JSON.stringify({
          notes: notes.map((n) => ({
            id: n.id,
            title: n.title,
            content: n.content,
            created: new Date(n.createdAt).toLocaleDateString(),
          })),
          count: notes.length,
        });
      }

      case 'delete_note': {
        const deleted = await deleteNote(input.id as string);
        return JSON.stringify({
          success: deleted,
          message: deleted ? 'Note deleted.' : 'Note not found.',
        });
      }

      case 'remember_fact': {
        await rememberFact(input.key as string, input.value as string);
        return JSON.stringify({ success: true, message: `Remembered: ${input.key} = ${input.value}` });
      }

      case 'recall_facts': {
        const memories: UserMemory[] = await recallFacts();
        if (memories.length === 0) {
          return JSON.stringify({ memories: [], message: 'No facts remembered yet.' });
        }
        return JSON.stringify({
          memories: memories.map((m) => ({ key: m.key, value: m.value })),
          count: memories.length,
        });
      }

      case 'get_datetime': {
        const now = new Date();
        return JSON.stringify({
          iso: now.toISOString(),
          date: now.toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' }),
          time: now.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', second: '2-digit' }),
          timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
          unix: Math.floor(now.getTime() / 1000),
        });
      }

      case 'schedule_reminder': {
        const delayMinutes = Math.max(1, input.delay_minutes as number);
        const triggerMs = delayMinutes * 60 * 1000;
        const scheduledFor = Date.now() + triggerMs;

        // Request permissions
        const { status } = await Notifications.requestPermissionsAsync();
        if (status !== 'granted') {
          return JSON.stringify({
            success: false,
            message: 'Notification permission not granted. Please enable notifications in Settings.',
          });
        }

        const notificationId = await Notifications.scheduleNotificationAsync({
          content: {
            title: 'Aria Reminder',
            body: input.message as string,
            sound: true,
          },
          trigger: { seconds: delayMinutes * 60 },
        });

        const reminder: Reminder = {
          id: `reminder_${Date.now()}`,
          message: input.message as string,
          scheduledFor,
          notificationId,
        };
        await saveReminder(reminder);

        return JSON.stringify({
          success: true,
          reminder_id: reminder.id,
          message: `Reminder set for ${delayMinutes} minute${delayMinutes !== 1 ? 's' : ''} from now.`,
          scheduled_for: new Date(scheduledFor).toLocaleTimeString(),
        });
      }

      case 'get_reminders': {
        const reminders: Reminder[] = await loadReminders();
        const now = Date.now();
        const upcoming = reminders.filter((r) => r.scheduledFor > now);
        return JSON.stringify({
          reminders: upcoming.map((r) => ({
            id: r.id,
            message: r.message,
            scheduled_for: new Date(r.scheduledFor).toLocaleString(),
          })),
          count: upcoming.length,
        });
      }

      default:
        return JSON.stringify({ error: `Unknown tool: ${name}` });
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return JSON.stringify({ error: message });
  }
}
