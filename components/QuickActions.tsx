import React from 'react';
import {
  ScrollView,
  Pressable,
  Text,
  StyleSheet,
  View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Colors } from '@/constants/colors';

interface QuickAction {
  label: string;
  icon: keyof typeof Ionicons.glyphMap;
  prompt: string;
}

const QUICK_ACTIONS: QuickAction[] = [
  { label: 'Summarize my day', icon: 'sunny-outline', prompt: 'Give me a quick summary of what I should focus on today.' },
  { label: 'Save a note', icon: 'document-text-outline', prompt: 'I want to save a note.' },
  { label: 'Set a reminder', icon: 'alarm-outline', prompt: 'Set a reminder for me.' },
  { label: 'What time is it?', icon: 'time-outline', prompt: 'What is the current date and time?' },
  { label: 'My saved notes', icon: 'folder-outline', prompt: 'Show me all my saved notes.' },
  { label: 'Brainstorm ideas', icon: 'bulb-outline', prompt: 'Help me brainstorm some ideas.' },
];

interface Props {
  onSelect: (prompt: string) => void;
  visible: boolean;
}

export function QuickActions({ onSelect, visible }: Props) {
  if (!visible) return null;

  return (
    <View style={styles.wrapper}>
      <Text style={styles.label}>Quick actions</Text>
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.list}
      >
        {QUICK_ACTIONS.map((action) => (
          <Pressable
            key={action.label}
            style={({ pressed }) => [styles.chip, pressed && styles.chipPressed]}
            onPress={() => onSelect(action.prompt)}
          >
            <Ionicons name={action.icon} size={14} color={Colors.textSecondary} />
            <Text style={styles.chipText}>{action.label}</Text>
          </Pressable>
        ))}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    paddingTop: 12,
    paddingBottom: 4,
    backgroundColor: Colors.background,
  },
  label: {
    color: Colors.textMuted,
    fontSize: 11,
    paddingHorizontal: 16,
    marginBottom: 8,
    textTransform: 'uppercase',
    letterSpacing: 0.8,
  },
  list: {
    paddingHorizontal: 12,
    gap: 8,
    flexDirection: 'row',
  },
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: Colors.card,
    borderRadius: 16,
    paddingHorizontal: 12,
    paddingVertical: 7,
    borderWidth: 1,
    borderColor: Colors.border,
  },
  chipPressed: {
    backgroundColor: Colors.cardHover,
  },
  chipText: {
    color: Colors.textSecondary,
    fontSize: 13,
  },
});
