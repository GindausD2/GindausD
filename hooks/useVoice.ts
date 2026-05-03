import { useState, useCallback, useRef } from 'react';
import * as Speech from 'expo-speech';
import { AssistantSettings } from '@/types';

export function useVoice(settings: AssistantSettings | null) {
  const [isSpeaking, setIsSpeaking] = useState(false);
  const currentTextRef = useRef<string>('');

  const speak = useCallback(
    (text: string) => {
      if (!settings?.voiceEnabled) return;

      // Strip markdown for clean speech
      const cleaned = text
        .replace(/\*\*(.+?)\*\*/g, '$1')        // bold
        .replace(/\*(.+?)\*/g, '$1')             // italic
        .replace(/`(.+?)`/g, '$1')               // inline code
        .replace(/```[\s\S]*?```/g, '')          // code blocks
        .replace(/#+\s/g, '')                    // headings
        .replace(/\[(.+?)\]\(.+?\)/g, '$1')      // links
        .replace(/[>*_~]/g, '')                  // misc markdown
        .trim();

      if (!cleaned) return;
      currentTextRef.current = cleaned;

      Speech.stop();
      setIsSpeaking(true);

      Speech.speak(cleaned, {
        rate: settings.voiceSpeed,
        pitch: settings.voicePitch,
        onDone: () => setIsSpeaking(false),
        onStopped: () => setIsSpeaking(false),
        onError: () => setIsSpeaking(false),
      });
    },
    [settings]
  );

  const stop = useCallback(() => {
    Speech.stop();
    setIsSpeaking(false);
  }, []);

  return { speak, stop, isSpeaking };
}
