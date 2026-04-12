import React, { useRef, useEffect, useCallback, useState } from 'react';
import {
  View,
  Text,
  Pressable,
  StyleSheet,
  Alert,
  Dimensions,
  Animated,
  ScrollView,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import * as Haptics from 'expo-haptics';

import { Orb } from '@/components/Orb';
import { useChat } from '@/hooks/useChat';
import { useSettings } from '@/hooks/useSettings';
import { useVoice } from '@/hooks/useVoice';
import { useVoiceRecorder } from '@/hooks/useVoiceRecorder';
import { Message } from '@/types';

const { width: SCREEN_W, height: SCREEN_H } = Dimensions.get('window');

// ─── Clock ───────────────────────────────────────────────────────────────────

function useClock() {
  const [time, setTime] = useState(new Date());
  useEffect(() => {
    const id = setInterval(() => setTime(new Date()), 1000);
    return () => clearInterval(id);
  }, []);
  return time;
}

function formatClock(d: Date): string {
  const h = d.getHours().toString().padStart(2, '0');
  const m = d.getMinutes().toString().padStart(2, '0');
  const s = d.getSeconds().toString().padStart(2, '0');
  return `${h}-${m}-${s}`;
}

// ─── Transcript bubble ────────────────────────────────────────────────────────

function TranscriptBubble({ message, isLatest }: { message: Message; isLatest: boolean }) {
  const fadeAnim = useRef(new Animated.Value(0)).current;
  const slideAnim = useRef(new Animated.Value(8)).current;

  useEffect(() => {
    Animated.parallel([
      Animated.timing(fadeAnim, {
        toValue: isLatest ? 1 : 0.55,
        duration: 280,
        useNativeDriver: true,
      }),
      Animated.timing(slideAnim, {
        toValue: 0,
        duration: 280,
        useNativeDriver: true,
      }),
    ]).start();
  }, [isLatest]);

  const isUser = message.role === 'user';

  // Strip markdown stars/hashes for cleaner transcript display
  const cleanText = message.content
    .replace(/\*\*(.+?)\*\*/g, '$1')
    .replace(/\*(.+?)\*/g, '$1')
    .replace(/#+\s/g, '')
    .trim();

  return (
    <Animated.View
      style={[
        styles.bubbleRow,
        isUser ? styles.bubbleRowUser : styles.bubbleRowAI,
        { opacity: fadeAnim, transform: [{ translateY: slideAnim }] },
      ]}
    >
      <View style={[styles.bubble, isUser ? styles.bubbleUser : styles.bubbleAI]}>
        <Text style={[styles.bubbleText, isUser ? styles.bubbleTextUser : styles.bubbleTextAI]}>
          {cleanText}
        </Text>
      </View>
    </Animated.View>
  );
}

// ─── Main screen ─────────────────────────────────────────────────────────────

export default function HomeScreen() {
  const { settings, isLoaded } = useSettings();
  const apiKey = settings?.apiKey ?? '';

  const {
    messages,
    isLoading,
    activeToolName,
    sendMessage,
    clearConversation,
    stopStreaming,
    error,
  } = useChat(apiKey);

  const { speak, stop: stopSpeaking, isSpeaking } = useVoice(settings);
  const voiceRecorder = useVoiceRecorder(settings);

  const now = useClock();
  const scrollRef = useRef<ScrollView>(null);
  const micScale = useRef(new Animated.Value(1)).current;

  // Auto-scroll transcript to bottom
  useEffect(() => {
    const id = setTimeout(() => scrollRef.current?.scrollToEnd({ animated: true }), 80);
    return () => clearTimeout(id);
  }, [messages.length, isLoading]);

  // Auto-speak AI responses
  useEffect(() => {
    if (!settings?.voiceEnabled) return;
    const last = messages[messages.length - 1];
    if (last?.role === 'assistant' && !last.isStreaming && last.content) {
      speak(last.content);
    }
  }, [messages, speak, settings?.voiceEnabled]);

  // Mic button press animation
  const animateMicPress = (pressed: boolean) => {
    Animated.spring(micScale, {
      toValue: pressed ? 0.88 : 1,
      useNativeDriver: true,
      speed: 30,
    }).start();
  };

  // Derive orb state
  type OrbState = 'idle' | 'listening' | 'thinking' | 'speaking';
  let orbState: OrbState = 'idle';
  if (voiceRecorder.state === 'recording') orbState = 'listening';
  else if (voiceRecorder.state === 'transcribing' || isLoading) orbState = 'thinking';
  else if (isSpeaking) orbState = 'speaking';

  // Voice stop → transcribe → send
  const handleVoiceToggle = useCallback(async () => {
    if (voiceRecorder.state === 'recording') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
      const transcript = await voiceRecorder.stopAndTranscribe();
      if (transcript) {
        sendMessage(transcript);
      } else if (voiceRecorder.errorMessage) {
        Alert.alert('Voice Error', voiceRecorder.errorMessage);
      }
    } else if ((voiceRecorder.state === 'idle' || voiceRecorder.state === 'error') && !isLoading) {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
      await voiceRecorder.startRecording();
    }
  }, [voiceRecorder, isLoading, sendMessage]);

  const handleStopAll = useCallback(() => {
    stopSpeaking();
    stopStreaming();
    voiceRecorder.cancel();
  }, [stopSpeaking, stopStreaming, voiceRecorder]);

  const handleClear = useCallback(() => {
    Alert.alert('New conversation', 'Start fresh with Max?', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Clear',
        style: 'destructive',
        onPress: () => {
          handleStopAll();
          clearConversation();
        },
      },
    ]);
  }, [handleStopAll, clearConversation]);

  // Visible transcript: last 6 non-empty messages (skip welcome-only state)
  const allReal = messages.filter((m) => m.content.trim());
  const transcript = allReal.length <= 1 ? [] : allReal.slice(-6);

  const isRecording = voiceRecorder.state === 'recording';
  const isTranscribing = voiceRecorder.state === 'transcribing';
  const isBusy = isLoading || isTranscribing;

  return (
    <SafeAreaView style={styles.safeArea} edges={['top', 'bottom']}>
      {/* ── Top bar ─────────────────────────────────────────────────────── */}
      <View style={styles.topBar}>
        <Pressable onPress={handleClear} hitSlop={12} style={styles.topBtn}>
          <Ionicons name="refresh-outline" size={22} color="#999" />
        </Pressable>

        <Text style={styles.appName}>{settings?.assistantName ?? 'Max'}</Text>

        <Pressable onPress={() => router.push('/settings')} hitSlop={12} style={styles.topBtn}>
          <Ionicons name="settings-outline" size={22} color="#999" />
        </Pressable>
      </View>

      {/* ── Transcript area ──────────────────────────────────────────────── */}
      <View style={styles.transcriptArea}>
        {error ? (
          <View style={styles.errorBox}>
            <Ionicons name="alert-circle-outline" size={16} color="#EF4444" />
            <Text style={styles.errorText} numberOfLines={2}>{error}</Text>
          </View>
        ) : transcript.length === 0 ? (
          <View style={styles.emptyState}>
            <Text style={styles.emptyLine1}>
              {isRecording ? 'Listening...' : `Hi, I'm Max`}
            </Text>
            <Text style={styles.emptyLine2}>
              {isRecording ? 'Tap stop when done' : 'Tap the mic and start talking'}
            </Text>
          </View>
        ) : (
          <ScrollView
            ref={scrollRef}
            style={styles.scroll}
            contentContainerStyle={styles.scrollContent}
            showsVerticalScrollIndicator={false}
          >
            {transcript.map((m, i) => (
              <TranscriptBubble
                key={m.id}
                message={m}
                isLatest={i === transcript.length - 1}
              />
            ))}
          </ScrollView>
        )}
      </View>

      {/* ── Bottom canvas with gradient + orb ───────────────────────────── */}
      <View style={styles.bottomCanvas}>
        {/* Gradient fade */}
        <LinearGradient
          colors={['rgba(255,255,255,0)', 'rgba(240,240,245,1)']}
          style={styles.gradientFade}
          pointerEvents="none"
        />

        {/* Status row: clock + orb state label */}
        <View style={styles.statusRow}>
          <Text style={styles.clock}>{formatClock(now)}</Text>
          {activeToolName && (
            <Text style={styles.toolLabel}>
              {activeToolName.replace(/_/g, ' ')}...
            </Text>
          )}
          {isSpeaking && !activeToolName && (
            <Text style={styles.toolLabel}>Speaking</Text>
          )}
          {isRecording && !activeToolName && (
            <Text style={[styles.toolLabel, { color: '#EF4444' }]}>Recording</Text>
          )}
        </View>

        {/* Orb row */}
        <View style={styles.orbRow}>
          {/* Stop / placeholder left */}
          <Pressable
            style={styles.sideBtn}
            onPress={isBusy || isSpeaking ? handleStopAll : undefined}
            hitSlop={12}
          >
            {(isBusy || isSpeaking) ? (
              <Ionicons name="stop-circle-outline" size={28} color="#999" />
            ) : (
              <Ionicons name="chatbubble-outline" size={26} color="#ccc" />
            )}
          </Pressable>

          {/* Central orb */}
          <Pressable onPress={handleVoiceToggle} disabled={isBusy}>
            <Orb state={orbState} size={128} />
          </Pressable>

          {/* Mic button */}
          <Pressable
            onPressIn={() => animateMicPress(true)}
            onPressOut={() => animateMicPress(false)}
            onPress={handleVoiceToggle}
            disabled={isBusy}
            hitSlop={12}
            style={styles.sideBtn}
          >
            <Animated.View style={{ transform: [{ scale: micScale }] }}>
              <Ionicons
                name={isRecording ? 'mic' : 'mic-outline'}
                size={30}
                color={isRecording ? '#EF4444' : '#999'}
              />
            </Animated.View>
          </Pressable>
        </View>

        {/* Blue progress / active indicator bar */}
        <View style={styles.indicatorBar}>
          <Animated.View
            style={[
              styles.indicatorFill,
              {
                width: isRecording || isBusy || isSpeaking ? '100%' : '0%',
                backgroundColor: isRecording ? '#EF4444' : '#4F46E5',
              },
            ]}
          />
        </View>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#FFFFFF',
  },

  // ── Top bar ─────────────────────────────────────────────────────────────
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 24,
    paddingTop: 4,
    paddingBottom: 12,
  },
  topBtn: {
    width: 38,
    height: 38,
    alignItems: 'center',
    justifyContent: 'center',
  },
  appName: {
    fontSize: 18,
    fontWeight: '600',
    color: '#1A1A2E',
    letterSpacing: 1.5,
  },

  // ── Transcript ───────────────────────────────────────────────────────────
  transcriptArea: {
    flex: 1,
    paddingHorizontal: 16,
  },
  scroll: { flex: 1 },
  scrollContent: {
    flexGrow: 1,
    justifyContent: 'flex-end',
    gap: 6,
    paddingBottom: 12,
    paddingTop: 8,
  },
  // Row wrappers control alignment
  bubbleRow: {
    flexDirection: 'row',
    marginHorizontal: 4,
  },
  bubbleRowUser: {
    justifyContent: 'flex-end',
  },
  bubbleRowAI: {
    justifyContent: 'flex-start',
  },
  // The speech bubble itself
  bubble: {
    maxWidth: '78%',
    borderRadius: 20,
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  bubbleUser: {
    backgroundColor: '#E8E8EA',       // light gray — matches mockup
    borderBottomRightRadius: 5,
  },
  bubbleAI: {
    backgroundColor: '#FFFFFF',        // white card
    borderBottomLeftRadius: 5,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.07,
    shadowRadius: 4,
    elevation: 2,
  },
  bubbleText: {
    fontSize: 15,
    lineHeight: 22,
  },
  bubbleTextUser: {
    color: '#1A1A2E',
  },
  bubbleTextAI: {
    color: '#1A1A2E',
  },
  emptyState: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
  },
  emptyLine1: {
    fontSize: 20,
    fontWeight: '500',
    color: '#1A1A2E',
  },
  emptyLine2: {
    fontSize: 14,
    color: '#999',
  },
  errorBox: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: '#FFF1F1',
    borderRadius: 12,
    paddingHorizontal: 14,
    paddingVertical: 10,
    marginTop: 12,
  },
  errorText: {
    flex: 1,
    color: '#EF4444',
    fontSize: 13,
  },

  // ── Bottom canvas ────────────────────────────────────────────────────────
  bottomCanvas: {
    paddingBottom: 8,
    backgroundColor: 'transparent',
  },
  gradientFade: {
    position: 'absolute',
    top: -60,
    left: 0,
    right: 0,
    height: 80,
  },
  statusRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 28,
    marginBottom: 4,
  },
  clock: {
    fontSize: 22,
    fontWeight: '300',
    color: '#1A1A2E',
    letterSpacing: 2,
    fontVariant: ['tabular-nums'],
  },
  toolLabel: {
    fontSize: 13,
    color: '#7C3AED',
    fontWeight: '500',
  },
  orbRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 32,
  },
  sideBtn: {
    width: 52,
    height: 52,
    alignItems: 'center',
    justifyContent: 'center',
  },

  // ── Indicator bar ────────────────────────────────────────────────────────
  indicatorBar: {
    height: 3,
    backgroundColor: '#E5E7EB',
    marginTop: 12,
    overflow: 'hidden',
  },
  indicatorFill: {
    height: 3,
    borderRadius: 2,
  },
});
