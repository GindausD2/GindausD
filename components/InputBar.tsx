import React, { useState, useRef, useCallback } from 'react';
import {
  View,
  TextInput,
  Pressable,
  StyleSheet,
  Text,
  Keyboard,
  ActivityIndicator,
  Animated,
  Platform,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { Colors } from '@/constants/colors';

interface Props {
  onSend: (text: string) => void;
  onStop: () => void;
  isLoading: boolean;
  activeToolName?: string | null;
  disabled?: boolean;
  // Voice recorder props
  voiceState?: 'idle' | 'recording' | 'transcribing' | 'error';
  voiceDurationMs?: number;
  onVoiceStart?: () => void;
  onVoiceStop?: () => void;
  onVoiceCancel?: () => void;
}

function formatDuration(ms: number): string {
  const secs = Math.floor(ms / 1000);
  const mins = Math.floor(secs / 60);
  const s = secs % 60;
  return `${mins}:${s.toString().padStart(2, '0')}`;
}

export function InputBar({
  onSend,
  onStop,
  isLoading,
  activeToolName,
  disabled,
  voiceState = 'idle',
  voiceDurationMs = 0,
  onVoiceStart,
  onVoiceStop,
  onVoiceCancel,
}: Props) {
  const [text, setText] = useState('');
  const inputRef = useRef<TextInput>(null);
  const pulseAnim = useRef(new Animated.Value(1)).current;

  // Pulse animation when recording
  React.useEffect(() => {
    if (voiceState === 'recording') {
      const pulse = Animated.loop(
        Animated.sequence([
          Animated.timing(pulseAnim, { toValue: 1.3, duration: 600, useNativeDriver: true }),
          Animated.timing(pulseAnim, { toValue: 1, duration: 600, useNativeDriver: true }),
        ])
      );
      pulse.start();
      return () => pulse.stop();
    } else {
      pulseAnim.setValue(1);
    }
  }, [voiceState]);

  const handleSend = useCallback(() => {
    const trimmed = text.trim();
    if (!trimmed || isLoading) return;
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    onSend(trimmed);
    setText('');
    Keyboard.dismiss();
  }, [text, isLoading, onSend]);

  const handleStop = useCallback(() => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    onStop();
  }, [onStop]);

  const handleMicPress = useCallback(() => {
    if (voiceState === 'recording') {
      onVoiceStop?.();
    } else if (voiceState === 'idle') {
      Keyboard.dismiss();
      onVoiceStart?.();
    }
  }, [voiceState, onVoiceStart, onVoiceStop]);

  const isRecording = voiceState === 'recording';
  const isTranscribing = voiceState === 'transcribing';
  const canSend = text.trim().length > 0 && !isLoading && !isRecording && !isTranscribing;
  const showMic = !text.trim() && !isLoading;

  // ── Recording overlay ──────────────────────────────────────────────────────
  if (isRecording || isTranscribing) {
    return (
      <View style={styles.wrapper}>
        <View style={styles.recordingContainer}>
          {/* Cancel swipe hint */}
          <Pressable onPress={onVoiceCancel} style={styles.cancelButton}>
            <Ionicons name="close-circle" size={22} color={Colors.textMuted} />
            <Text style={styles.cancelText}>Cancel</Text>
          </Pressable>

          {/* Waveform / status */}
          <View style={styles.recordingCenter}>
            {isTranscribing ? (
              <>
                <ActivityIndicator size="small" color={Colors.primary} />
                <Text style={styles.recordingStatus}>Transcribing...</Text>
              </>
            ) : (
              <>
                <View style={styles.waveform}>
                  {[...Array(5)].map((_, i) => (
                    <Animated.View
                      key={i}
                      style={[
                        styles.waveBar,
                        {
                          height: 8 + (i % 3) * 8,
                          opacity: pulseAnim.interpolate({
                            inputRange: [1, 1.3],
                            outputRange: [0.5, 1],
                          }),
                        },
                      ]}
                    />
                  ))}
                </View>
                <Text style={styles.recordingDuration}>{formatDuration(voiceDurationMs)}</Text>
              </>
            )}
          </View>

          {/* Stop button */}
          <Animated.View style={{ transform: [{ scale: pulseAnim }] }}>
            <Pressable
              style={styles.micStopButton}
              onPress={handleMicPress}
              disabled={isTranscribing}
            >
              <Ionicons name="stop" size={20} color="#fff" />
            </Pressable>
          </Animated.View>
        </View>
      </View>
    );
  }

  // ── Normal input ───────────────────────────────────────────────────────────
  return (
    <View style={styles.wrapper}>
      {activeToolName && (
        <View style={styles.toolBanner}>
          <ActivityIndicator size="small" color={Colors.primary} />
          <Text style={styles.toolBannerText}>
            Using {activeToolName.replace(/_/g, ' ')}...
          </Text>
        </View>
      )}

      <View style={styles.container}>
        {/* Mic button (left) - only when no text */}
        {showMic && onVoiceStart && (
          <Pressable
            style={styles.micIdleButton}
            onPress={handleMicPress}
            hitSlop={8}
          >
            <Ionicons name="mic" size={22} color={Colors.textSecondary} />
          </Pressable>
        )}

        <TextInput
          ref={inputRef}
          style={[styles.input, !showMic && styles.inputNoMic]}
          value={text}
          onChangeText={setText}
          placeholder="Message Max..."
          placeholderTextColor={Colors.textMuted}
          multiline
          maxLength={4000}
          returnKeyType="default"
          editable={!disabled && !isLoading}
          selectionColor={Colors.primary}
        />

        {/* Send / Stop (right) */}
        {isLoading ? (
          <Pressable
            style={[styles.actionButton, styles.stopButton]}
            onPress={handleStop}
            hitSlop={8}
          >
            <Ionicons name="stop" size={18} color="#fff" />
          </Pressable>
        ) : (
          canSend && (
            <Pressable
              style={[styles.actionButton, styles.sendButton]}
              onPress={handleSend}
              hitSlop={8}
            >
              <Ionicons name="arrow-up" size={20} color="#fff" />
            </Pressable>
          )
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    backgroundColor: Colors.surface,
    borderTopWidth: 1,
    borderTopColor: Colors.border,
    paddingBottom: 4,
  },
  toolBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    paddingHorizontal: 16,
    paddingVertical: 6,
    backgroundColor: Colors.card,
  },
  toolBannerText: {
    color: Colors.textSecondary,
    fontSize: 12,
  },
  container: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    paddingHorizontal: 12,
    paddingVertical: 8,
    gap: 8,
  },
  input: {
    flex: 1,
    backgroundColor: Colors.inputBg,
    borderRadius: 22,
    borderWidth: 1,
    borderColor: Colors.border,
    paddingHorizontal: 16,
    paddingVertical: 10,
    paddingTop: 10,
    color: Colors.textPrimary,
    fontSize: 15,
    lineHeight: 20,
    maxHeight: 120,
  },
  inputNoMic: {
    // no change needed — mic isn't shown
  },
  micIdleButton: {
    width: 38,
    height: 38,
    borderRadius: 19,
    backgroundColor: Colors.card,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 1,
  },
  actionButton: {
    width: 38,
    height: 38,
    borderRadius: 19,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 1,
  },
  sendButton: {
    backgroundColor: Colors.primary,
  },
  stopButton: {
    backgroundColor: Colors.error,
  },
  // ── Recording UI ────────────────────────────────────────────────────────────
  recordingContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 14,
    gap: 12,
  },
  cancelButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  cancelText: {
    color: Colors.textMuted,
    fontSize: 13,
  },
  recordingCenter: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 10,
  },
  waveform: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  waveBar: {
    width: 4,
    backgroundColor: Colors.error,
    borderRadius: 2,
  },
  recordingStatus: {
    color: Colors.textSecondary,
    fontSize: 14,
  },
  recordingDuration: {
    color: Colors.error,
    fontSize: 15,
    fontWeight: '600',
    fontVariant: ['tabular-nums'],
  },
  micStopButton: {
    width: 42,
    height: 42,
    borderRadius: 21,
    backgroundColor: Colors.error,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
