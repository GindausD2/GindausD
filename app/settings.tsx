import React, { useEffect, useState } from 'react';
import { View, Text, TextInput, Pressable, StyleSheet, ScrollView, Switch, Alert, ActivityIndicator } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { GlassSurface } from '@/components/GlassSurface';
import { useSettings } from '@/hooks/useSettings';
import { useAuth } from '@/hooks/useAuth';
import { clearMessages, loadNotes, loadMemories } from '@/services/storage';
import { signOut } from '@/services/auth';
import { Colors as C } from '@/constants/colors';
function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return <View style={styles.section}><Text style={styles.sectionTitle}>{title}</Text><GlassSurface style={styles.card}>{children}</GlassSurface></View>;
}
function Row({ icon, title, subtitle, action, trailing, danger }: { icon: keyof typeof Ionicons.glyphMap; title: string; subtitle?: string; action?: () => void; trailing?: React.ReactNode; danger?: boolean }) {
  const content = <><View style={styles.rowIcon}><Ionicons name={icon} size={20} color={danger ? C.error : C.textPrimary} /></View><View style={styles.rowText}><Text style={[styles.rowTitle, danger && { color: C.error }]}>{title}</Text>{subtitle ? <Text style={styles.rowSubtitle}>{subtitle}</Text> : null}</View>{trailing || (action ? <Ionicons name="chevron-forward" size={16} color={C.textMuted} /> : null)}</>;
  return action ? <Pressable accessibilityRole="button" onPress={action} style={({ pressed }) => [styles.row, pressed && { opacity: 0.65 }]}>{content}</Pressable> : <View style={styles.row}>{content}</View>;
}
export default function SettingsScreen() {
  const { settings, updateSettings } = useSettings();
  const { user, isLoading: authLoading } = useAuth();
  const [name, setName] = useState('');
  const [saving, setSaving] = useState(false);
  const hydrated = React.useRef(false);
  useEffect(() => { if (settings && !authLoading && !hydrated.current) { setName(settings.userName || user?.name || ''); hydrated.current = true; } }, [settings, user?.name, authLoading]);
  const save = async () => {
    setSaving(true);
    try { await updateSettings({ userName: name.trim() }); router.back(); }
    catch { Alert.alert('Couldn’t save', 'Please try again.'); }
    finally { setSaving(false); }
  };
  const stats = async () => { const [notes, memories] = await Promise.all([loadNotes(), loadMemories()]); Alert.alert('Your saved things', `${notes.length} notes · ${memories.length} memories`); };
  const clear = () => Alert.alert('Clear conversation history?', 'This deletes messages saved on this device.', [{ text: 'Cancel', style: 'cancel' }, { text: 'Clear history', style: 'destructive', onPress: () => { void clearMessages(); } }]);
  const logout = () => Alert.alert('Sign out of Max?', '', [{ text: 'Cancel', style: 'cancel' }, { text: 'Sign out', onPress: async () => { await signOut(); router.replace('/welcome'); } }]);
  return <View style={styles.root}>
    <LinearGradient colors={['#F9F7F2', '#F0EEE7', '#DCE4DA']} style={StyleSheet.absoluteFill} />
    <SafeAreaView style={styles.safe}>
      <View style={styles.header}><Pressable accessibilityRole="button" accessibilityLabel="Close settings" onPress={() => router.back()} style={styles.close}><Ionicons name="close" size={21} color={C.textPrimary} /></Pressable><Text style={styles.headerTitle}>Settings</Text><Pressable accessibilityRole="button" onPress={save} disabled={saving || !settings} style={styles.done}>{saving ? <ActivityIndicator color={C.primary} /> : <Text style={styles.doneText}>Done</Text>}</Pressable></View>
      {!settings ? <ActivityIndicator style={{ marginTop: 60 }} color={C.primary} /> : <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled" showsVerticalScrollIndicator={false}>
        <View style={styles.profile}><GlassSurface style={styles.avatar}><Text style={styles.initial}>{(name || 'M').slice(0, 1).toUpperCase()}</Text></GlassSurface><Text style={styles.profileName}>{name || 'Your space'}</Text><Text style={styles.profileSubtitle}>Make Max feel like you.</Text></View>
        <Section title="PERSONAL"><Row icon="person-outline" title="Your name" trailing={<TextInput accessibilityLabel="Your name" value={name} onChangeText={setName} placeholder="Add name" placeholderTextColor={C.textMuted} autoCapitalize="words" style={styles.nameInput} />} /></Section>
        <Section title="YOUR ASSISTANT"><Row icon="volume-medium-outline" title="Spoken replies" subtitle="Let Max read responses aloud" trailing={<Switch accessibilityLabel="Spoken replies" value={settings.voiceEnabled} onValueChange={async value => { try { await updateSettings({ voiceEnabled: value }); } catch { Alert.alert('Couldn’t save', 'Please try again.'); } }} trackColor={{ false: '#D4D8D0', true: '#697C67' }} thumbColor="#FFFFFF" />} /></Section>
        <Section title="SAVED ON THIS DEVICE"><Row icon="leaf-outline" title="Notes & memories" subtitle="The things you’ve asked Max to keep" action={stats} /><View style={styles.divider} /><Row icon="trash-outline" title="Clear conversation history" action={clear} danger /></Section>
        <Section title="ACCOUNT"><Row icon="log-out-outline" title="Sign out" action={logout} /></Section>
        <View style={styles.about}><Text style={styles.aboutBrand}>Max.</Text><Text style={styles.aboutText}>A little help. A little more space.</Text><Text style={styles.version}>Version 1.0</Text></View>
      </ScrollView>}
    </SafeAreaView>
  </View>;
}
const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: C.background }, safe: { flex: 1 }, header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 20, paddingVertical: 14 },
  close: { width: 44, height: 44, borderRadius: 22, backgroundColor: 'rgba(255,255,255,0.65)', alignItems: 'center', justifyContent: 'center' }, headerTitle: { fontSize: 16, fontWeight: '600', color: C.textPrimary }, done: { minWidth: 44, minHeight: 44, justifyContent: 'center', alignItems: 'center' }, doneText: { fontSize: 15, fontWeight: '600', color: C.textPrimary },
  content: { paddingHorizontal: 22, paddingBottom: 36 }, profile: { alignItems: 'center', paddingTop: 24, paddingBottom: 36 }, avatar: { width: 78, height: 78, borderRadius: 39, alignItems: 'center', justifyContent: 'center' }, initial: { fontSize: 28, fontWeight: '400', color: C.textPrimary },
  profileName: { fontSize: 28, letterSpacing: -0.8, fontWeight: '500', color: C.textPrimary, marginTop: 18 }, profileSubtitle: { fontSize: 13, color: C.textSecondary, marginTop: 8 }, section: { marginBottom: 24 }, sectionTitle: { fontSize: 10, fontWeight: '600', letterSpacing: 1.7, color: C.textSecondary, marginBottom: 10, paddingLeft: 6 }, card: { borderRadius: 24 },
  row: { minHeight: 72, paddingHorizontal: 16, paddingVertical: 16, flexDirection: 'row', alignItems: 'center', gap: 12 }, rowIcon: { width: 28, alignItems: 'center' }, rowText: { flex: 1 }, rowTitle: { fontSize: 15, color: C.textPrimary }, rowSubtitle: { fontSize: 12, color: C.textSecondary, lineHeight: 18, marginTop: 5 }, divider: { height: 1, backgroundColor: '#E0E3DA', marginHorizontal: 18 }, nameInput: { width: 118, minHeight: 44, fontSize: 14, textAlign: 'right', color: C.textSecondary },
  about: { alignItems: 'center', paddingTop: 12 }, aboutBrand: { fontSize: 25, fontWeight: '500', letterSpacing: -1, color: C.textPrimary }, aboutText: { marginTop: 8, fontSize: 12, color: C.textSecondary }, version: { marginTop: 12, fontSize: 10, color: C.textMuted },
});
