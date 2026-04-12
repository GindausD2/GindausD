import React, { memo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  Alert,
  Clipboard,
} from 'react-native';
import { Message } from '@/types';
import { Colors } from '@/constants/colors';

interface Props {
  message: Message;
  onSpeak?: (text: string) => void;
  isSpeaking?: boolean;
}

function formatTime(ts: number): string {
  return new Date(ts).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

// Simple markdown-to-styled-text renderer
function renderContent(text: string, isUser: boolean) {
  // Split by code blocks first
  const parts = text.split(/(```[\s\S]*?```)/g);

  return parts.map((part, i) => {
    if (part.startsWith('```')) {
      const code = part.replace(/^```\w*\n?/, '').replace(/```$/, '');
      return (
        <View key={i} style={styles.codeBlock}>
          <Text style={styles.codeText} selectable>{code.trim()}</Text>
        </View>
      );
    }

    // Process inline formatting
    const lines = part.split('\n');
    return (
      <View key={i}>
        {lines.map((line, li) => {
          if (!line.trim()) {
            return <Text key={li} style={{ height: 6 }} />;
          }

          // Bullet points
          if (line.match(/^[-*•]\s/)) {
            const content = line.replace(/^[-*•]\s/, '');
            return (
              <View key={li} style={styles.bulletRow}>
                <Text style={[styles.bullet, isUser && styles.userText]}>•</Text>
                <Text style={[styles.bulletText, isUser && styles.userText]} selectable>
                  {renderInline(content, isUser)}
                </Text>
              </View>
            );
          }

          // Numbered list
          const numMatch = line.match(/^(\d+)\.\s(.+)/);
          if (numMatch) {
            return (
              <View key={li} style={styles.bulletRow}>
                <Text style={[styles.bullet, isUser && styles.userText]}>{numMatch[1]}.</Text>
                <Text style={[styles.bulletText, isUser && styles.userText]} selectable>
                  {renderInline(numMatch[2], isUser)}
                </Text>
              </View>
            );
          }

          // Heading
          const h1Match = line.match(/^##\s(.+)/);
          if (h1Match) {
            return <Text key={li} style={[styles.heading, isUser && styles.userText]}>{h1Match[1]}</Text>;
          }
          const h2Match = line.match(/^###\s(.+)/);
          if (h2Match) {
            return <Text key={li} style={[styles.subheading, isUser && styles.userText]}>{h2Match[1]}</Text>;
          }

          return (
            <Text key={li} style={[styles.bodyText, isUser && styles.userText]} selectable>
              {renderInline(line, isUser)}
            </Text>
          );
        })}
      </View>
    );
  });
}

function renderInline(text: string, isUser: boolean): React.ReactNode {
  // Bold: **text**
  const parts = text.split(/(\*\*[^*]+\*\*|`[^`]+`)/g);
  if (parts.length === 1) return text;

  return parts.map((part, i) => {
    if (part.startsWith('**') && part.endsWith('**')) {
      return (
        <Text key={i} style={[styles.bold, isUser && styles.userText]}>
          {part.slice(2, -2)}
        </Text>
      );
    }
    if (part.startsWith('`') && part.endsWith('`')) {
      return (
        <Text key={i} style={[styles.inlineCode, isUser && styles.userInlineCode]}>
          {part.slice(1, -1)}
        </Text>
      );
    }
    return part;
  });
}

export const ChatBubble = memo(function ChatBubble({ message, onSpeak, isSpeaking }: Props) {
  const isUser = message.role === 'user';

  const handleLongPress = () => {
    Alert.alert('Message Options', '', [
      {
        text: 'Copy',
        onPress: () => Clipboard.setString(message.content),
      },
      ...(onSpeak && !isUser
        ? [
            {
              text: isSpeaking ? 'Stop Speaking' : 'Speak',
              onPress: () => onSpeak(message.content),
            },
          ]
        : []),
      { text: 'Cancel', style: 'cancel' as const },
    ]);
  };

  return (
    <Pressable
      onLongPress={handleLongPress}
      style={[styles.container, isUser && styles.containerUser]}
    >
      {!isUser && (
        <View style={styles.avatarContainer}>
          <View style={styles.avatar}>
            <Text style={styles.avatarText}>A</Text>
          </View>
        </View>
      )}

      <View style={[styles.bubble, isUser ? styles.userBubble : styles.aiBubble]}>
        {renderContent(message.content || '', isUser)}
        <Text style={[styles.timestamp, isUser && styles.userTimestamp]}>
          {formatTime(message.timestamp)}
        </Text>
      </View>
    </Pressable>
  );
});

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    paddingHorizontal: 12,
    paddingVertical: 4,
    alignItems: 'flex-end',
    gap: 8,
  },
  containerUser: {
    flexDirection: 'row-reverse',
  },
  avatarContainer: {
    width: 30,
    alignItems: 'center',
  },
  avatar: {
    width: 30,
    height: 30,
    borderRadius: 15,
    backgroundColor: Colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '700',
  },
  bubble: {
    maxWidth: '80%',
    borderRadius: 18,
    padding: 12,
    paddingHorizontal: 14,
  },
  userBubble: {
    backgroundColor: Colors.userBubble,
    borderBottomRightRadius: 4,
  },
  aiBubble: {
    backgroundColor: Colors.aiBubble,
    borderBottomLeftRadius: 4,
  },
  bodyText: {
    color: Colors.aiBubbleText,
    fontSize: 15,
    lineHeight: 22,
  },
  userText: {
    color: Colors.userBubbleText,
  },
  bold: {
    fontWeight: '700',
    color: Colors.aiBubbleText,
  },
  heading: {
    fontSize: 16,
    fontWeight: '700',
    color: Colors.aiBubbleText,
    marginTop: 6,
    marginBottom: 2,
  },
  subheading: {
    fontSize: 15,
    fontWeight: '600',
    color: Colors.aiBubbleText,
    marginTop: 4,
    marginBottom: 2,
  },
  bulletRow: {
    flexDirection: 'row',
    gap: 6,
    marginVertical: 1,
  },
  bullet: {
    color: Colors.textSecondary,
    fontSize: 15,
    lineHeight: 22,
  },
  bulletText: {
    flex: 1,
    color: Colors.aiBubbleText,
    fontSize: 15,
    lineHeight: 22,
  },
  inlineCode: {
    fontFamily: 'monospace',
    backgroundColor: 'rgba(255,255,255,0.1)',
    paddingHorizontal: 4,
    paddingVertical: 1,
    borderRadius: 4,
    fontSize: 13,
    color: Colors.secondaryLight,
  },
  userInlineCode: {
    backgroundColor: 'rgba(255,255,255,0.2)',
    color: '#fff',
  },
  codeBlock: {
    backgroundColor: Colors.surface,
    borderRadius: 8,
    padding: 10,
    marginVertical: 4,
    borderLeftWidth: 3,
    borderLeftColor: Colors.primary,
  },
  codeText: {
    fontFamily: 'monospace',
    fontSize: 12,
    color: Colors.secondaryLight,
    lineHeight: 18,
  },
  timestamp: {
    fontSize: 10,
    color: Colors.textMuted,
    marginTop: 4,
    textAlign: 'right',
  },
  userTimestamp: {
    color: 'rgba(255,255,255,0.6)',
  },
});
