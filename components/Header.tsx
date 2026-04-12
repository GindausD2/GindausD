import React from 'react';
import {
  View,
  Text,
  Pressable,
  StyleSheet,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { Colors } from '@/constants/colors';

interface Props {
  onClearChat?: () => void;
  isSpeaking?: boolean;
  onStopSpeaking?: () => void;
  assistantName?: string;
}

export function Header({ onClearChat, isSpeaking, onStopSpeaking, assistantName = 'Max' }: Props) {
  return (
    <View style={styles.container}>
      {/* Left: avatar + name */}
      <View style={styles.identity}>
        <View style={styles.avatarRing}>
          <View style={styles.avatar}>
            <Text style={styles.avatarLetter}>{assistantName[0]}</Text>
          </View>
          {/* Online dot */}
          <View style={styles.onlineDot} />
        </View>

        <View>
          <Text style={styles.name}>{assistantName}</Text>
          <Text style={styles.subtitle}>
            {isSpeaking ? 'Speaking...' : 'AI Assistant'}
          </Text>
        </View>
      </View>

      {/* Right: actions */}
      <View style={styles.actions}>
        {isSpeaking && (
          <Pressable
            style={styles.iconButton}
            onPress={onStopSpeaking}
            hitSlop={8}
          >
            <Ionicons name="volume-mute" size={22} color={Colors.textSecondary} />
          </Pressable>
        )}

        <Pressable
          style={styles.iconButton}
          onPress={onClearChat}
          hitSlop={8}
        >
          <Ionicons name="trash-outline" size={20} color={Colors.textSecondary} />
        </Pressable>

        <Pressable
          style={styles.iconButton}
          onPress={() => router.push('/settings')}
          hitSlop={8}
        >
          <Ionicons name="settings-outline" size={22} color={Colors.textSecondary} />
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: Colors.surface,
    borderBottomWidth: 1,
    borderBottomColor: Colors.border,
  },
  identity: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  avatarRing: {
    position: 'relative',
  },
  avatar: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: Colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarLetter: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '700',
  },
  onlineDot: {
    position: 'absolute',
    bottom: 0,
    right: 0,
    width: 11,
    height: 11,
    borderRadius: 6,
    backgroundColor: Colors.success,
    borderWidth: 2,
    borderColor: Colors.surface,
  },
  name: {
    color: Colors.textPrimary,
    fontSize: 16,
    fontWeight: '700',
  },
  subtitle: {
    color: Colors.textSecondary,
    fontSize: 12,
  },
  actions: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  iconButton: {
    width: 38,
    height: 38,
    borderRadius: 19,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
