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

import { useSettings } from '@/hooks/useSettings';
import { clearMessages, loadNotes, loadMemories } from '@/services/storage';

// ─── Light palette ────────────────────────────────────────────────────────────
const C = {
  bg: '#F5F5F7',
  surface: '#FFFFFF',
  card: '#FFFFFF',
  border: '#E5E7EB',
  primary: '#4F46E5',
  danger: '#EF4444',
  textPrimary: '#1A1A2E',
  textSecondary: '#6B7280',
  textMuted: '#9CA3AF',
  inputBg: '#F9FAFB',
};

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
  first,
}: {
  icon: keyof typeof import('@expo/vector-icons').Ionicons.glyphMap;
  label: string;
  sublabel?: string;
  right?: React.ReactNode;
  onPress?: () => void;
  danger?: boolean;
  first?: boolean;
}) {
  return (
    <Pressable
      style={({ pressed }) => [
        styles.row,
        !first && styles.rowBorder,
        pressed && onPress && styles.rowPressed,
      ]}
      onPress={onPress}
    >
      <View style={[styles.rowIcon, danger && styles.rowIconDanger]}>
        <Ionicons name={icon} size={17} color={danger ? C.danger : C.primary} />
      </View>
      <View style={styles.rowContent}>
        <Text style={[styles.rowLabel, danger && styles.rowLabelDanger]}>{label}</Text>
        {sublabel && <Text style={styles.rowSublabel}>{sublabel}</Text>}
      </View>
      {right ?? (onPress ? <Ionicons name="chevron-forward" size={15} color={C.textMuted} /> : null)}
    </Pressable>
  );
}

export default function SettingsScreen() {
  const { settings, updateSettings } = useSettings();
  const [apiKey, setApiKey] = useState(settings?.apiKey ?? '');
  const [userName, setUserName] = useState(settings?.userName ?? '');
  const [isSaving, setIsSaving] = useState(false);
  const [showKey, setShowKey] = useState(false);

  const handleSave = useCallback(async () => {
    setIsSaving(true);
    await updateSettings({ apiKey: apiKey.trim(), userName: userName.trim() });
    setIsSaving(false);
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    router.back();
  }, [apiKey, userName, updateSettings]);

  const handleToggleVoice = useCallback(
    (val: boolean) => updateSettings({ voiceEnabled: val }),
    [updateSettings]
  );

  const handleClearHistory = useCallback(() => {
    Alert.alert('Clear Chat History', 'Permanently delete all messages?', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          await clearMessages();
          Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
        },
      },
    ]);
  }, []);

  const handleStats = useCallback(async () => {
    const notes = await loadNotes();
    const memories = await loadMemories();
    Alert.alert('Stored Data', `Notes: ${notes.length}\nMemories: ${memories.length}`);
  }, []);

  if (!settings) {
    return (
      <SafeAreaView style={styles.safeArea}>
        <ActivityIndicator color={C.primary} />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.safeArea} edges={['top', 'bottom']}>
      {/* Header */}
      <View style={styles.header}>
        <Pressable onPress={() => router.back()} hitSlop={12}>
          <Ionicons name="close" size={22} color={C.textPrimary} />
        </Pressable>
        <Text style={styles.headerTitle}>Settings</Text>
        <Pressable onPress={handleSave} disabled={isSaving} hitSlop={12}>
          {isSaving
            ? <ActivityIndicator size="small" color={C.primary} />
            : <Text style={styles.saveBtn}>Save</Text>}
        </Pressable>
      </View>

      <ScrollView style={styles.scroll} contentContainerStyle={styles.scrollContent}>

        {/* API Key */}
        <Section title="Anthropic API Key">
          <View style={styles.keyField}>
            <TextInput
              style={styles.keyInput}
              value={apiKey}
              onChangeText={setApiKey}
              placeholder="sk-ant-..."
              placeholderTextColor={C.textMuted}
              secureTextEntry={!showKey}
              autoCapitalize="none"
              autoCorrect={false}
              selectionColor={C.primary}
            />
            <Pressable onPress={() => setShowKey(v => !v)} hitSlop={8} style={styles.eyeBtn}>
              <Ionicons name={showKey ? 'eye-off-outline' : 'eye-outline'} size={19} color={C.textMuted} />
            </Pressable>
          </View>
          <Text style={styles.hint}>
            Get yours at console.anthropic.com — stored only on your device.
          </Text>
        </Section>

        {/* Profile */}
        <Section title="Profile">
          <TextInput
            style={styles.nameInput}
            value={userName}
            onChangeText={setUserName}
            placeholder="Your name (so Max knows you)"
            placeholderTextColor={C.textMuted}
            autoCapitalize="words"
            selectionColor={C.primary}
          />
        </Section>

        {/* Voice */}
        <Section title="Voice">
          <Row
            icon="volume-high-outline"
            label="Voice Responses"
            sublabel="Max speaks replies aloud"
            first
            right={
              <Switch
                value={settings.voiceEnabled}
                onValueChange={handleToggleVoice}
                trackColor={{ false: C.border, true: C.primary }}
                thumbColor="#fff"
              />
            }
          />
        </Section>

        {/* Data */}
        <Section title="Data">
          <Row icon="bar-chart-outline" label="Storage Stats" sublabel="Notes & memories" onPress={handleStats} first />
          <Row icon="trash-outline" label="Clear History" danger onPress={handleClearHistory} />
        </Section>

        {/* About */}
        <Section title="About">
          <View style={styles.aboutCard}>
            <View style={styles.aboutOrb}>
              <Text style={styles.aboutOrbText}>M</Text>
            </View>
            <Text style={styles.aboutName}>{settings.assistantName}</Text>
            <Text style={styles.aboutSub}>AI Personal Assistant · v1.0</Text>
            <Text style={styles.aboutPowered}>Powered by Claude claude-sonnet-4-6</Text>
          </View>
        </Section>

      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: { flex: 1, backgroundColor: C.bg },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingVertical: 14,
    backgroundColor: C.surface,
    borderBottomWidth: 1,
    borderBottomColor: C.border,
  },
  headerTitle: { fontSize: 16, fontWeight: '600', color: C.textPrimary },
  saveBtn: { fontSize: 15, fontWeight: '600', color: C.primary },
  scroll: { flex: 1 },
  scrollContent: { padding: 16, paddingBottom: 48, gap: 8 },
  section: { marginBottom: 16 },
  sectionTitle: {
    fontSize: 11,
    fontWeight: '600',
    textTransform: 'uppercase',
    letterSpacing: 0.9,
    color: C.textMuted,
    marginBottom: 6,
    paddingHorizontal: 4,
  },
  sectionCard: {
    backgroundColor: C.card,
    borderRadius: 14,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: C.border,
  },
  // Key input
  keyField: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 14,
    paddingVertical: 10,
    gap: 8,
  },
  keyInput: {
    flex: 1,
    backgroundColor: C.inputBg,
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 9,
    fontFamily: 'monospace',
    fontSize: 13,
    color: C.textPrimary,
    borderWidth: 1,
    borderColor: C.border,
  },
  eyeBtn: { padding: 4 },
  hint: { fontSize: 11, color: C.textMuted, paddingHorizontal: 14, paddingBottom: 12, lineHeight: 16 },
  // Name input
  nameInput: {
    paddingHorizontal: 16,
    paddingVertical: 13,
    fontSize: 15,
    color: C.textPrimary,
  },
  // Rows
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 14,
    paddingVertical: 13,
    gap: 12,
  },
  rowBorder: { borderTopWidth: 1, borderTopColor: C.border },
  rowPressed: { backgroundColor: '#F9FAFB' },
  rowIcon: {
    width: 30,
    height: 30,
    borderRadius: 8,
    backgroundColor: 'rgba(79,70,229,0.1)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  rowIconDanger: { backgroundColor: 'rgba(239,68,68,0.1)' },
  rowContent: { flex: 1 },
  rowLabel: { fontSize: 15, color: C.textPrimary },
  rowLabelDanger: { color: C.danger },
  rowSublabel: { fontSize: 12, color: C.textMuted, marginTop: 1 },
  // About
  aboutCard: { alignItems: 'center', paddingVertical: 28, gap: 5 },
  aboutOrb: {
    width: 54,
    height: 54,
    borderRadius: 27,
    backgroundColor: '#4F46E5',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 6,
  },
  aboutOrbText: { fontSize: 24, fontWeight: '700', color: '#fff' },
  aboutName: { fontSize: 17, fontWeight: '700', color: C.textPrimary },
  aboutSub: { fontSize: 13, color: C.textSecondary },
  aboutPowered: { fontSize: 11, color: C.textMuted },
});
