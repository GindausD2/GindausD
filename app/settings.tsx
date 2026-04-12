import React, { useState, useCallback } from 'react';
import {
  View,
  Text,
  TextInput,
  Pressable,
  StyleSheet,
  ScrollView,
  Switch,
  Alert,
  ActivityIndicator,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';

import { Colors } from '@/constants/colors';
import { useSettings } from '@/hooks/useSettings';
import { clearMessages, loadNotes, loadMemories } from '@/services/storage';

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>{title}</Text>
      <View style={styles.sectionCard}>{children}</View>
    </View>
  );
}

function Row({
  icon,
  label,
  sublabel,
  right,
  onPress,
  danger,
}: {
  icon: keyof typeof import('@expo/vector-icons').Ionicons.glyphMap;
  label: string;
  sublabel?: string;
  right?: React.ReactNode;
  onPress?: () => void;
  danger?: boolean;
}) {
  return (
    <Pressable
      style={({ pressed }) => [styles.row, pressed && onPress && styles.rowPressed]}
      onPress={onPress}
    >
      <View style={[styles.rowIcon, danger && styles.rowIconDanger]}>
        <Ionicons name={icon} size={18} color={danger ? Colors.error : Colors.primary} />
      </View>
      <View style={styles.rowContent}>
        <Text style={[styles.rowLabel, danger && styles.rowLabelDanger]}>{label}</Text>
        {sublabel && <Text style={styles.rowSublabel}>{sublabel}</Text>}
      </View>
      {right ?? (onPress && !right ? (
        <Ionicons name="chevron-forward" size={16} color={Colors.textMuted} />
      ) : null)}
    </Pressable>
  );
}

export default function SettingsScreen() {
  const { settings, updateSettings } = useSettings();
  const [apiKey, setApiKey] = useState(settings?.apiKey ?? '');
  const [userName, setUserName] = useState(settings?.userName ?? '');
  const [isSaving, setIsSaving] = useState(false);
  const [showApiKey, setShowApiKey] = useState(false);

  const handleSave = useCallback(async () => {
    setIsSaving(true);
    await updateSettings({ apiKey: apiKey.trim(), userName: userName.trim() });
    setIsSaving(false);
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    router.back();
  }, [apiKey, userName, updateSettings]);

  const handleToggleVoice = useCallback(
    (val: boolean) => {
      updateSettings({ voiceEnabled: val });
    },
    [updateSettings]
  );

  const handleClearHistory = useCallback(() => {
    Alert.alert('Clear Chat History', 'This will permanently delete all messages.', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Clear',
        style: 'destructive',
        onPress: async () => {
          await clearMessages();
          Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
          Alert.alert('Done', 'Chat history cleared.');
        },
      },
    ]);
  }, []);

  const handleShowStats = useCallback(async () => {
    const notes = await loadNotes();
    const memories = await loadMemories();
    Alert.alert(
      'Your Data',
      `Notes: ${notes.length}\nMemories: ${memories.length}`,
      [{ text: 'OK' }]
    );
  }, []);

  if (!settings) {
    return (
      <SafeAreaView style={styles.safeArea}>
        <ActivityIndicator color={Colors.primary} />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.safeArea} edges={['top', 'bottom']}>
      {/* Header */}
      <View style={styles.header}>
        <Pressable onPress={() => router.back()} hitSlop={12}>
          <Ionicons name="close" size={24} color={Colors.textPrimary} />
        </Pressable>
        <Text style={styles.headerTitle}>Settings</Text>
        <Pressable onPress={handleSave} hitSlop={12} disabled={isSaving}>
          {isSaving ? (
            <ActivityIndicator size="small" color={Colors.primary} />
          ) : (
            <Text style={styles.saveButton}>Save</Text>
          )}
        </Pressable>
      </View>

      <ScrollView style={styles.scroll} contentContainerStyle={styles.scrollContent}>
        {/* API Key */}
        <Section title="API Key">
          <Text style={styles.apiKeyLabel}>Anthropic API Key</Text>
          <View style={styles.apiKeyRow}>
            <TextInput
              style={styles.apiKeyInput}
              value={apiKey}
              onChangeText={setApiKey}
              placeholder="sk-ant-..."
              placeholderTextColor={Colors.textMuted}
              secureTextEntry={!showApiKey}
              autoCapitalize="none"
              autoCorrect={false}
              selectionColor={Colors.primary}
            />
            <Pressable onPress={() => setShowApiKey((v) => !v)} hitSlop={8}>
              <Ionicons
                name={showApiKey ? 'eye-off-outline' : 'eye-outline'}
                size={20}
                color={Colors.textMuted}
              />
            </Pressable>
          </View>
          <Text style={styles.apiKeyHint}>
            Get your key at console.anthropic.com. It stays on your device.
          </Text>
        </Section>

        {/* Profile */}
        <Section title="Profile">
          <Text style={styles.apiKeyLabel}>Your Name (optional)</Text>
          <TextInput
            style={styles.textInput}
            value={userName}
            onChangeText={setUserName}
            placeholder="So Max can address you personally"
            placeholderTextColor={Colors.textMuted}
            autoCapitalize="words"
            selectionColor={Colors.primary}
          />
        </Section>

        {/* Voice */}
        <Section title="Voice">
          <Row
            icon="volume-high-outline"
            label="Voice Responses"
            sublabel="Max speaks replies aloud"
            right={
              <Switch
                value={settings.voiceEnabled}
                onValueChange={handleToggleVoice}
                trackColor={{ false: Colors.border, true: Colors.primary }}
                thumbColor="#fff"
              />
            }
          />
        </Section>

        {/* Data */}
        <Section title="Data">
          <Row
            icon="analytics-outline"
            label="Storage Stats"
            sublabel="Notes, memories saved locally"
            onPress={handleShowStats}
          />
          <Row
            icon="trash-outline"
            label="Clear Chat History"
            danger
            onPress={handleClearHistory}
          />
        </Section>

        {/* About */}
        <Section title="About">
          <View style={styles.aboutCard}>
            <View style={styles.aboutAvatar}>
              <Text style={styles.aboutAvatarText}>M</Text>
            </View>
            <Text style={styles.aboutName}>{settings.assistantName}</Text>
            <Text style={styles.aboutVersion}>AI Personal Assistant · v1.0</Text>
            <Text style={styles.aboutPowered}>Powered by Claude claude-sonnet-4-6</Text>
          </View>
        </Section>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: Colors.surface,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingVertical: 14,
    borderBottomWidth: 1,
    borderBottomColor: Colors.border,
  },
  headerTitle: {
    color: Colors.textPrimary,
    fontSize: 17,
    fontWeight: '600',
  },
  saveButton: {
    color: Colors.primary,
    fontSize: 16,
    fontWeight: '600',
  },
  scroll: {
    flex: 1,
    backgroundColor: Colors.background,
  },
  scrollContent: {
    padding: 16,
    gap: 8,
    paddingBottom: 40,
  },
  section: {
    marginBottom: 20,
  },
  sectionTitle: {
    color: Colors.textMuted,
    fontSize: 12,
    fontWeight: '600',
    textTransform: 'uppercase',
    letterSpacing: 0.8,
    marginBottom: 8,
    paddingHorizontal: 4,
  },
  sectionCard: {
    backgroundColor: Colors.card,
    borderRadius: 14,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: Colors.border,
  },
  apiKeyLabel: {
    color: Colors.textSecondary,
    fontSize: 13,
    marginBottom: 8,
    paddingHorizontal: 16,
    paddingTop: 14,
  },
  apiKeyRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingBottom: 4,
    gap: 8,
  },
  apiKeyInput: {
    flex: 1,
    color: Colors.textPrimary,
    fontSize: 14,
    fontFamily: 'monospace',
    paddingVertical: 8,
    backgroundColor: Colors.inputBg,
    borderRadius: 8,
    paddingHorizontal: 12,
    borderWidth: 1,
    borderColor: Colors.border,
  },
  apiKeyHint: {
    color: Colors.textMuted,
    fontSize: 12,
    paddingHorizontal: 16,
    paddingBottom: 14,
    paddingTop: 6,
    lineHeight: 18,
  },
  textInput: {
    color: Colors.textPrimary,
    fontSize: 15,
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: Colors.inputBg,
    borderRadius: 8,
    marginHorizontal: 16,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: Colors.border,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 14,
    gap: 14,
    borderTopWidth: 1,
    borderTopColor: Colors.border,
  },
  rowPressed: {
    backgroundColor: Colors.cardHover,
  },
  rowIcon: {
    width: 32,
    height: 32,
    borderRadius: 8,
    backgroundColor: 'rgba(124,58,237,0.12)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  rowIconDanger: {
    backgroundColor: 'rgba(239,68,68,0.12)',
  },
  rowContent: {
    flex: 1,
  },
  rowLabel: {
    color: Colors.textPrimary,
    fontSize: 15,
  },
  rowLabelDanger: {
    color: Colors.error,
  },
  rowSublabel: {
    color: Colors.textMuted,
    fontSize: 12,
    marginTop: 1,
  },
  aboutCard: {
    alignItems: 'center',
    paddingVertical: 24,
    gap: 6,
  },
  aboutAvatar: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: Colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 4,
  },
  aboutAvatarText: {
    color: '#fff',
    fontSize: 26,
    fontWeight: '700',
  },
  aboutName: {
    color: Colors.textPrimary,
    fontSize: 18,
    fontWeight: '700',
  },
  aboutVersion: {
    color: Colors.textSecondary,
    fontSize: 13,
  },
  aboutPowered: {
    color: Colors.textMuted,
    fontSize: 12,
  },
});
