import React, { useRef, useEffect, useCallback, useState } from 'react';
import {
  View,
  FlatList,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
  Alert,
  Text,
  Pressable,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';

import { Header } from '@/components/Header';
import { ChatBubble } from '@/components/ChatBubble';
import { TypingIndicator } from '@/components/TypingIndicator';
import { InputBar } from '@/components/InputBar';
import { QuickActions } from '@/components/QuickActions';

import { useChat } from '@/hooks/useChat';
import { useSettings } from '@/hooks/useSettings';
import { useVoice } from '@/hooks/useVoice';
import { useVoiceRecorder } from '@/hooks/useVoiceRecorder';

import { Colors } from '@/constants/colors';
import { Message } from '@/types';

export default function ChatScreen() {
  const { settings, isLoaded } = useSettings();
  const apiKey = settings?.apiKey ?? '';

  const { messages, isLoading, error, activeToolName, sendMessage, clearConversation, stopStreaming } =
    useChat(apiKey);

  const { speak, stop: stopSpeaking, isSpeaking } = useVoice(settings);
  const voiceRecorder = useVoiceRecorder(settings);

  const flatListRef = useRef<FlatList<Message>>(null);
  const [showQuickActions, setShowQuickActions] = useState(true);

  // Auto-scroll to bottom when messages change
  useEffect(() => {
    if (messages.length > 0) {
      setTimeout(() => {
        flatListRef.current?.scrollToEnd({ animated: true });
      }, 100);
    }
  }, [messages.length, isLoading]);

  // Auto-read last AI message if voice is enabled
  useEffect(() => {
    if (!settings?.voiceEnabled) return;
    const last = messages[messages.length - 1];
    if (last?.role === 'assistant' && !last.isStreaming && last.content) {
      speak(last.content);
    }
  }, [messages]);

  const handleSend = useCallback(
    (text: string) => {
      setShowQuickActions(false);
      sendMessage(text);
    },
    [sendMessage]
  );

  const handleClearChat = useCallback(() => {
    Alert.alert('Clear Chat', 'Start a fresh conversation with Max?', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Clear',
        style: 'destructive',
        onPress: () => {
          stopSpeaking();
          clearConversation();
          setShowQuickActions(true);
        },
      },
    ]);
  }, [clearConversation, stopSpeaking]);

  // Voice: stop → transcribe → send
  const handleVoiceStop = useCallback(async () => {
    const transcript = await voiceRecorder.stopAndTranscribe();
    if (transcript) {
      handleSend(transcript);
    } else if (voiceRecorder.errorMessage) {
      Alert.alert('Voice Error', voiceRecorder.errorMessage);
    }
  }, [voiceRecorder, handleSend]);

  const renderItem = useCallback(
    ({ item }: { item: Message }) => (
      <ChatBubble
        message={item}
        onSpeak={speak}
        isSpeaking={isSpeaking}
      />
    ),
    [speak, isSpeaking]
  );

  const keyExtractor = useCallback((item: Message) => item.id, []);

  if (!isLoaded) {
    return (
      <SafeAreaView style={styles.safeArea} edges={['top']}>
        <View style={styles.loadingContainer}>
          <Text style={styles.loadingText}>Starting Max...</Text>
        </View>
      </SafeAreaView>
    );
  }

  // Show setup prompt if no API key
  const noApiKey = !apiKey;

  return (
    <SafeAreaView style={styles.safeArea} edges={['top']}>
      <KeyboardAvoidingView
        style={styles.flex}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        keyboardVerticalOffset={0}
      >
        <Header
          onClearChat={handleClearChat}
          isSpeaking={isSpeaking}
          onStopSpeaking={stopSpeaking}
          assistantName={settings?.assistantName ?? 'Max'}
        />

        {/* API Key warning banner */}
        {noApiKey && (
          <Pressable
            style={styles.apiBanner}
            onPress={() => {
              const { router } = require('expo-router');
              router.push('/settings');
            }}
          >
            <Ionicons name="warning-outline" size={16} color={Colors.warning} />
            <Text style={styles.apiBannerText}>
              Tap to add your Anthropic API key in Settings
            </Text>
            <Ionicons name="chevron-forward" size={14} color={Colors.warning} />
          </Pressable>
        )}

        {/* Error banner */}
        {error && (
          <View style={styles.errorBanner}>
            <Ionicons name="alert-circle-outline" size={16} color={Colors.error} />
            <Text style={styles.errorBannerText} numberOfLines={2}>{error}</Text>
          </View>
        )}

        {/* Message list */}
        <FlatList
          ref={flatListRef}
          data={messages}
          renderItem={renderItem}
          keyExtractor={keyExtractor}
          style={styles.messageList}
          contentContainerStyle={styles.messageContent}
          showsVerticalScrollIndicator={false}
          keyboardDismissMode="interactive"
          ListFooterComponent={
            isLoading ? (
              <TypingIndicator toolName={activeToolName} />
            ) : null
          }
        />

        {/* Quick actions (shown on empty/fresh conversation) */}
        <QuickActions
          visible={showQuickActions && messages.length <= 1}
          onSelect={handleSend}
        />

        {/* Input bar with voice */}
        <InputBar
          onSend={handleSend}
          onStop={stopStreaming}
          isLoading={isLoading}
          activeToolName={activeToolName}
          voiceState={voiceRecorder.state}
          voiceDurationMs={voiceRecorder.durationMs}
          onVoiceStart={voiceRecorder.startRecording}
          onVoiceStop={handleVoiceStop}
          onVoiceCancel={voiceRecorder.cancel}
        />

        <SafeAreaView edges={['bottom']} style={styles.bottomSafe} />
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: Colors.surface,
  },
  flex: {
    flex: 1,
    backgroundColor: Colors.background,
  },
  loadingContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  loadingText: {
    color: Colors.textSecondary,
    fontSize: 16,
  },
  apiBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: 'rgba(245,158,11,0.1)',
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(245,158,11,0.2)',
    paddingHorizontal: 16,
    paddingVertical: 10,
  },
  apiBannerText: {
    flex: 1,
    color: Colors.warning,
    fontSize: 13,
  },
  errorBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: 'rgba(239,68,68,0.1)',
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(239,68,68,0.2)',
    paddingHorizontal: 16,
    paddingVertical: 10,
  },
  errorBannerText: {
    flex: 1,
    color: Colors.error,
    fontSize: 13,
  },
  messageList: {
    flex: 1,
  },
  messageContent: {
    paddingVertical: 12,
    flexGrow: 1,
    justifyContent: 'flex-end',
  },
  bottomSafe: {
    backgroundColor: Colors.surface,
  },
});
