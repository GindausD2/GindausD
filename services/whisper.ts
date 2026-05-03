/**
 * Voice transcription via OpenAI Whisper API.
 * Records audio with expo-av and sends to Whisper for speech-to-text.
 * Falls back to Claude's audio input if no OpenAI key is available.
 */

import { Audio } from 'expo-av';
import * as FileSystem from 'expo-file-system';

export interface RecordingResult {
  uri: string;
  durationMs: number;
}

let _recording: Audio.Recording | null = null;

/**
 * Start recording audio.
 * Call stopRecording() to end and get the file URI.
 */
export async function startRecording(): Promise<void> {
  await Audio.requestPermissionsAsync();
  await Audio.setAudioModeAsync({
    allowsRecordingIOS: true,
    playsInSilentModeIOS: true,
  });

  const { recording } = await Audio.Recording.createAsync(
    Audio.RecordingOptionsPresets.HIGH_QUALITY
  );
  _recording = recording;
}

/**
 * Stop recording and return the file URI + duration.
 */
export async function stopRecording(): Promise<RecordingResult | null> {
  if (!_recording) return null;

  await _recording.stopAndUnloadAsync();
  const status = await _recording.getStatusAsync();
  const uri = _recording.getURI();
  _recording = null;

  await Audio.setAudioModeAsync({ allowsRecordingIOS: false });

  if (!uri) return null;
  return {
    uri,
    durationMs: status.isLoaded ? status.durationMillis ?? 0 : 0,
  };
}

export async function cancelRecording(): Promise<void> {
  if (!_recording) return;
  try {
    await _recording.stopAndUnloadAsync();
  } catch {
    // ignore
  }
  _recording = null;
  await Audio.setAudioModeAsync({ allowsRecordingIOS: false });
}

/**
 * Transcribe audio using OpenAI Whisper API.
 * Requires an OpenAI API key.
 */
export async function transcribeWithWhisper(
  audioUri: string,
  openaiApiKey: string
): Promise<string> {
  // Read file as base64
  const base64 = await FileSystem.readAsStringAsync(audioUri, {
    encoding: FileSystem.EncodingType.Base64,
  });

  // Build multipart form data
  const formData = new FormData();
  formData.append('file', {
    uri: audioUri,
    type: 'audio/m4a',
    name: 'recording.m4a',
  } as unknown as Blob);
  formData.append('model', 'whisper-1');
  formData.append('language', 'en');

  const response = await fetch('https://api.openai.com/v1/audio/transcriptions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${openaiApiKey}`,
    },
    body: formData,
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Whisper API error: ${response.status} ${error}`);
  }

  const json = await response.json();
  return json.text as string;
}

/**
 * Transcribe audio using Claude's native audio input.
 * Sends the audio directly to Claude as a message attachment.
 */
export async function transcribeWithClaude(
  audioUri: string,
  anthropicApiKey: string
): Promise<string> {
  const base64Audio = await FileSystem.readAsStringAsync(audioUri, {
    encoding: FileSystem.EncodingType.Base64,
  });

  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': anthropicApiKey,
      'anthropic-version': '2023-06-01',
      'anthropic-beta': 'audio-1',
    },
    body: JSON.stringify({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 512,
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'audio',
              source: {
                type: 'base64',
                media_type: 'audio/mp4',
                data: base64Audio,
              },
            },
            {
              type: 'text',
              text: 'Please transcribe exactly what was said in this audio. Output only the transcription, nothing else.',
            },
          ],
        },
      ],
    }),
  });

  if (!response.ok) {
    throw new Error(`Claude transcription error: ${response.status}`);
  }

  const json = await response.json();
  const block = json.content?.[0];
  return block?.type === 'text' ? block.text : '';
}
