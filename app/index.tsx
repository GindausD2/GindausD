import React, { useCallback, useEffect, useRef, useState } from 'react';
import { View, Text, Pressable, StyleSheet, ScrollView, TextInput, KeyboardAvoidingView, Platform, Alert } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import { Ionicons } from '@expo/vector-icons';
import { router, Redirect } from 'expo-router';
import { Orb } from '@/components/Orb';
import { GlassSurface } from '@/components/GlassSurface';
import { useChat } from '@/hooks/useChat';
import { useSettings } from '@/hooks/useSettings';
import { useVoice } from '@/hooks/useVoice';
import { useVoiceRecorder } from '@/hooks/useVoiceRecorder';
import { useAuth } from '@/hooks/useAuth';
import { Colors as C } from '@/constants/colors';

const suggestions = ['Plan my day', 'Save a thought', 'Set a reminder'];
export default function HomeScreen() {
  const { user, isLoading: authLoading } = useAuth();
  const { settings } = useSettings();
  const { messages, isLoading, error, sendMessage, clearConversation, stopStreaming, activeToolName } = useChat(settings?.apiKey ?? '');
  const { speak, stop: stopSpeaking, isSpeaking } = useVoice(settings);
  const recorder = useVoiceRecorder(settings);
  const [draft, setDraft] = useState('');
  const scroll = useRef<ScrollView>(null);
  const spoken = useRef<string | null>(null);
  const last = messages[messages.length - 1];
  useEffect(() => {
    if (last?.role === 'assistant' && !last.isStreaming && last.content && settings?.voiceEnabled && spoken.current !== last.id) {
      spoken.current = last.id;
      speak(last.content);
    }
  }, [last, settings?.voiceEnabled, speak]);
  const busy = isLoading || recorder.state === 'transcribing';
  const listening = recorder.state === 'recording';
  const state = listening ? 'listening' : busy ? 'thinking' : isSpeaking ? 'speaking' : 'idle';
  const send = useCallback(() => { if (draft.trim()) { stopSpeaking(); void sendMessage(draft); if (settings?.apiKey) setDraft(''); } }, [draft, sendMessage, stopSpeaking, settings?.apiKey]);
  const toggleVoice = async () => {
    if (listening) { const text = await recorder.stopAndTranscribe(); if (text) void sendMessage(text); }
    else { stopSpeaking(); await recorder.startRecording(); }
  };
  const reset = () => Alert.alert('Start a new conversation?', 'Your current conversation will be cleared.', [
    { text: 'Cancel', style: 'cancel' }, { text: 'Start new', onPress: () => { stopStreaming(); stopSpeaking(); void recorder.cancel(); void clearConversation(); } },
  ]);
  if (authLoading) return null;
  if (!user) return <Redirect href="/welcome" />;
  const conversation = messages.filter(m => m.content.trim() && messages.indexOf(m) !== 0);
  return (
    <View style={styles.root}>
      <LinearGradient colors={['#F9F7F2', '#F0EEE7', '#DCE4DA']} style={StyleSheet.absoluteFill} />
      <SafeAreaView style={styles.safe} edges={['top', 'bottom']}>
        <KeyboardAvoidingView style={styles.safe} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
          <View style={styles.header}>
            <Pressable accessibilityRole="button" accessibilityLabel="New conversation" onPress={reset} style={styles.iconButton}><Ionicons name="add" size={23} color={C.textPrimary} /></Pressable>
            <Text style={styles.brand}>Max<Text style={styles.brandDot}>.</Text></Text>
            <Pressable accessibilityRole="button" accessibilityLabel="Open settings" onPress={() => router.push('/settings')} style={styles.iconButton}><Ionicons name="options-outline" size={22} color={C.textPrimary} /></Pressable>
          </View>
          <ScrollView ref={scroll} style={styles.conversation} contentContainerStyle={styles.conversationContent} keyboardShouldPersistTaps="handled" onContentSizeChange={() => { if (conversation.length > 0) scroll.current?.scrollToEnd({ animated: false }); }}>
            {conversation.length === 0 ? <View style={styles.hero}>
              <Text style={styles.eyebrow}>A LITTLE SPACE FOR YOUR DAY</Text>
              <Text style={styles.title}>Make room for{ '\n' }what matters.</Text>
              <Text style={styles.subtitle}>A thought, a plan, a little help.{ '\n' }Start wherever you are.</Text>
              <View style={styles.pearl}><Orb state={state} size={108} /></View>
              <Text style={styles.voiceHint}>{listening ? 'Listening · tap the mic to finish' : 'Speak naturally. Max is here.'}</Text>
              <View style={styles.suggestions}>{suggestions.map(text => <Pressable key={text} accessibilityRole="button" onPress={() => setDraft(text)}><GlassSurface style={styles.suggestion}><Text style={styles.suggestionText}>{text}</Text><Ionicons name="arrow-up-outline" size={14} color={C.textSecondary} /></GlassSurface></Pressable>)}</View>
            </View> : conversation.map(m => <View key={m.id} style={[styles.message, m.role === 'user' ? styles.userMessage : styles.assistantMessage]}><Text style={styles.messageLabel}>{m.role === 'user' ? 'YOU' : 'MAX'}</Text><Text selectable style={styles.messageText}>{m.content}</Text></View>)}
          </ScrollView>
          {error || recorder.errorMessage ? <Text accessibilityLiveRegion="polite" style={styles.error}>{error || recorder.errorMessage}</Text> : null}
          {state !== 'idle' ? <Text accessibilityLiveRegion="polite" style={styles.status}>{activeToolName ? activeToolName.replace(/_/g, ' ') : state === 'thinking' ? 'One moment…' : state === 'listening' ? 'Listening…' : 'Speaking…'}</Text> : null}
          <GlassSurface style={styles.composer}>
            <TextInput accessibilityLabel="Message Max" value={draft} onChangeText={setDraft} placeholder="Ask Max anything…" placeholderTextColor={C.textMuted} style={styles.input} onSubmitEditing={send} returnKeyType="send" editable={!busy && !listening} />
            <Pressable accessibilityRole="button" accessibilityLabel={busy || isSpeaking ? 'Stop response' : draft.trim() ? 'Send message' : listening ? 'Finish recording' : 'Start voice input'} style={styles.sendButton} onPress={busy || isSpeaking ? () => { stopStreaming(); stopSpeaking(); void recorder.cancel(); } : draft.trim() ? send : toggleVoice}>
              <Ionicons name={busy || isSpeaking ? 'stop' : draft.trim() ? 'arrow-up' : listening ? 'stop' : 'mic-outline'} size={21} color="#FFFFFF" />
            </Pressable>
          </GlassSurface>
          <Text style={styles.footer}>Your day, a little lighter.</Text>
        </KeyboardAvoidingView>
      </SafeAreaView>
    </View>
  );
}
const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: C.background }, safe: { flex: 1 },
  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 24, paddingTop: 10, paddingBottom: 20 },
  iconButton: { width: 46, height: 46, borderRadius: 23, backgroundColor: 'rgba(255,255,255,0.6)', borderWidth: 1, borderColor: '#FFFFFF', alignItems: 'center', justifyContent: 'center' },
  brand: { fontSize: 27, fontWeight: '600', letterSpacing: -1, color: C.textPrimary }, brandDot: { color: '#8B9A85' },
  conversation: { flex: 1 }, conversationContent: { flexGrow: 1, paddingHorizontal: 24, paddingBottom: 20 },
  hero: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingVertical: 24 },
  eyebrow: { fontSize: 10, letterSpacing: 2, color: C.textSecondary, fontWeight: '600', textAlign: 'center' },
  title: { fontSize: 39, lineHeight: 45, fontWeight: '400', letterSpacing: -1.5, textAlign: 'center', marginTop: 23, color: C.textPrimary },
  subtitle: { fontSize: 15, lineHeight: 24, color: C.textSecondary, textAlign: 'center', marginTop: 18 },
  pearl: { padding: 22, borderRadius: 100, backgroundColor: 'rgba(255,255,255,0.25)', marginTop: 30, marginBottom: 20, borderWidth: 1, borderColor: 'rgba(255,255,255,0.7)' },
  voiceHint: { fontSize: 12, color: C.textSecondary }, suggestions: { flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'center', gap: 8, marginTop: 26 },
  suggestion: { borderRadius: 18, paddingHorizontal: 14, paddingVertical: 12, flexDirection: 'row', alignItems: 'center', gap: 10 }, suggestionText: { fontSize: 14, color: C.textPrimary },
  message: { padding: 18, borderRadius: 24, marginTop: 12, maxWidth: '93%' }, userMessage: { alignSelf: 'flex-end', backgroundColor: '#E3E9DF' }, assistantMessage: { alignSelf: 'flex-start', backgroundColor: 'rgba(255,255,255,0.8)' },
  messageLabel: { fontSize: 9, letterSpacing: 1.5, color: C.textSecondary, marginBottom: 8 }, messageText: { fontSize: 16, lineHeight: 25, color: C.textPrimary },
  composer: { flexDirection: 'row', alignItems: 'center', marginHorizontal: 20, padding: 8, borderRadius: 32 }, input: { flex: 1, minHeight: 46, paddingHorizontal: 14, fontSize: 15, color: C.textPrimary },
  sendButton: { width: 46, height: 46, borderRadius: 23, backgroundColor: C.primary, alignItems: 'center', justifyContent: 'center' }, footer: { textAlign: 'center', marginVertical: 12, fontSize: 10, color: C.textSecondary },
  error: { marginHorizontal: 24, marginBottom: 12, fontSize: 13, lineHeight: 20, color: C.error }, status: { textAlign: 'center', marginBottom: 10, fontSize: 12, color: C.textSecondary },
});
