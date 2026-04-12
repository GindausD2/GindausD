import { useState, useCallback, useRef } from 'react';
import * as Haptics from 'expo-haptics';
import {
  startRecording,
  stopRecording,
  cancelRecording,
  transcribeWithClaude,
} from '@/services/whisper';
import { AssistantSettings } from '@/types';

type RecorderState = 'idle' | 'recording' | 'transcribing' | 'error';

interface UseVoiceRecorderResult {
  state: RecorderState;
  durationMs: number;
  startRecording: () => Promise<void>;
  stopAndTranscribe: () => Promise<string | null>;
  cancel: () => Promise<void>;
  errorMessage: string | null;
}

export function useVoiceRecorder(settings: AssistantSettings | null): UseVoiceRecorderResult {
  const [state, setState] = useState<RecorderState>('idle');
  const [durationMs, setDurationMs] = useState(0);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const startTimeRef = useRef<number>(0);

  const start = useCallback(async () => {
    try {
      setErrorMessage(null);
      await startRecording();
      setState('recording');
      startTimeRef.current = Date.now();
      setDurationMs(0);

      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);

      timerRef.current = setInterval(() => {
        setDurationMs(Date.now() - startTimeRef.current);
      }, 100);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      setErrorMessage(msg);
      setState('error');
    }
  }, []);

  const stopAndTranscribe = useCallback(async (): Promise<string | null> => {
    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }

    try {
      setState('transcribing');
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);

      const result = await stopRecording();
      if (!result) {
        setState('idle');
        return null;
      }

      let transcript = '';

      // Prefer Whisper if OpenAI key is set, fall back to Claude
      if (settings?.apiKey) {
        try {
          transcript = await transcribeWithClaude(result.uri, settings.apiKey);
        } catch {
          // Claude audio might not be supported in all regions; handle gracefully
          setErrorMessage('Voice transcription unavailable. Please type your message.');
          setState('error');
          return null;
        }
      } else {
        setErrorMessage('API key required for voice input. Set it in Settings.');
        setState('error');
        return null;
      }

      setState('idle');
      setDurationMs(0);
      return transcript.trim() || null;
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      setErrorMessage(msg);
      setState('error');
      return null;
    }
  }, [settings]);

  const cancel = useCallback(async () => {
    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }
    await cancelRecording();
    setState('idle');
    setDurationMs(0);
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
  }, []);

  return { state, durationMs, startRecording: start, stopAndTranscribe, cancel, errorMessage };
}
