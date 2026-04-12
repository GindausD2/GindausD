import { useState, useEffect, useCallback } from 'react';
import { AssistantSettings } from '@/types';
import { loadSettings, saveSettings } from '@/services/storage';

export function useSettings() {
  const [settings, setSettings] = useState<AssistantSettings | null>(null);
  const [isLoaded, setIsLoaded] = useState(false);

  useEffect(() => {
    loadSettings().then((s) => {
      setSettings(s);
      setIsLoaded(true);
    });
  }, []);

  const updateSettings = useCallback(async (updates: Partial<AssistantSettings>) => {
    const updated = await saveSettings(updates);
    setSettings(updated);
    return updated;
  }, []);

  return { settings, isLoaded, updateSettings };
}
