export type MessageRole = 'user' | 'assistant';

export interface Message {
  id: string;
  role: MessageRole;
  content: string;
  timestamp: number;
  isStreaming?: boolean;
  toolCalls?: ToolCall[];
}

export interface ToolCall {
  id: string;
  name: string;
  input: Record<string, unknown>;
  result?: string;
}

export interface Note {
  id: string;
  title: string;
  content: string;
  createdAt: number;
  updatedAt: number;
}

export interface UserMemory {
  key: string;
  value: string;
  updatedAt: number;
}

export interface Reminder {
  id: string;
  message: string;
  scheduledFor: number;
  notificationId?: string;
}

export interface AssistantSettings {
  apiKey: string;
  assistantName: string;
  voiceEnabled: boolean;
  voiceSpeed: number;
  voicePitch: number;
  userName: string;
  theme: 'dark' | 'light';
}

export interface ChatState {
  messages: Message[];
  isLoading: boolean;
  error: string | null;
}

export type ToolName =
  | 'save_note'
  | 'get_notes'
  | 'delete_note'
  | 'remember_fact'
  | 'recall_facts'
  | 'get_datetime'
  | 'schedule_reminder'
  | 'get_reminders'
  | 'clear_conversation';
