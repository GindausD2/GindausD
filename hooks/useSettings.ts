import { useState, useCallback } from 'react';
import { useFocusEffect } from 'expo-router';
import { AssistantSettings } from '@/types';
import { loadSettings, saveSettings } from '@/services/storage';

export function useSettings() {
  const [settings, setSettings] = useState<AssistantSettings | null>(null);
  const [isLoaded, setIsLoaded] = useState(false);

  useFocusEffect(useCallback(() => {
    let active = true;
    loadSettings().then((s) => {
      if (active) { setSettings(s); setIsLoaded(true); }
    });
    return () => { active = false; };
  }, []));

  const updateSettings = useCallback(async (updates: Partial<AssistantSettings>) => {
    const updated = await saveSettings(updates);
    setSettings(updated);
    return updated;
  }, []);

  return { settings, isLoaded, updateSettings };
}
