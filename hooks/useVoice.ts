import { useState, useCallback, useRef, useEffect } from 'react';
import { AppState, Platform } from 'react-native';
import * as Speech from 'expo-speech';
import * as Haptics from 'expo-haptics';
import { AssistantSettings } from '@/types';

export function useVoice(settings: AssistantSettings | null) {
  const [isSpeaking, setIsSpeaking] = useState(false);
  const generation = useRef(0);
  const haptics = useRef<ReturnType<typeof setInterval> | null>(null);
  const mounted = useRef(true);
  const clearHaptics = useCallback(() => {
    if (haptics.current) clearInterval(haptics.current);
    haptics.current = null;
  }, []);
  const stop = useCallback(() => {
    generation.current += 1;
    clearHaptics();
    void Speech.stop().catch(() => {});
    if (mounted.current) setIsSpeaking(false);
  }, [clearHaptics]);

  useEffect(() => {
    mounted.current = true;
    const subscription = AppState.addEventListener('change', state => { if (state !== 'active') stop(); });
    return () => { mounted.current = false; subscription.remove(); stop(); };
  }, [stop]);
  useEffect(() => { if (settings?.speakingHapticsEnabled === false) clearHaptics(); }, [settings?.speakingHapticsEnabled, clearHaptics]);

  const speak = useCallback((text: string, options?: { manual?: boolean }) => {
    if (!options?.manual && !settings?.voiceEnabled) return;
    const cleaned = text
      .replace(/```[\s\S]*?```/g, '')
      .replace(/\*\*(.+?)\*\*/g, '$1')
      .replace(/\*(.+?)\*/g, '$1')
      .replace(/`(.+?)`/g, '$1')
      .replace(/#+\s/g, '')
      .replace(/\[(.+?)\]\(.+?\)/g, '$1')
      .replace(/[>*_~]/g, '').trim();
    if (!cleaned) return;
    const id = ++generation.current;
    clearHaptics();
    const finish = () => {
      if (generation.current !== id || !mounted.current) return;
      clearHaptics(); setIsSpeaking(false);
    };
    // Serialize replacement speech so an old cancellation cannot stop the new reply.
    setIsSpeaking(true);
    void Speech.stop().then(() => {
      if (generation.current !== id || !mounted.current) return;
      Speech.speak(cleaned, {
        rate: settings?.voiceSpeed ?? 1,
        pitch: settings?.voicePitch ?? 1.05,
        onStart: () => {
          if (generation.current !== id || Platform.OS === 'web' || settings?.speakingHapticsEnabled === false) return;
          const pulse = () => { if (AppState.currentState === 'active') void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light).catch(() => {}); };
          pulse(); haptics.current = setInterval(pulse, 750);
        },
        onDone: finish, onStopped: finish, onError: finish,
      });
    }).catch(finish);
  }, [settings?.voiceEnabled, settings?.voiceSpeed, settings?.voicePitch, settings?.speakingHapticsEnabled, clearHaptics]);

  return { speak, stop, isSpeaking };
}
