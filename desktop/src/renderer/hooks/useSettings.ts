import { useEffect, useCallback } from 'react';
import { useAppStore } from '../stores/appStore';
import { api } from '../api/client';
import type { Settings } from '../types';


export function useSettings() {
  const settings = useAppStore((s) => s.settings);
  const setSettings = useAppStore((s) => s.setSettings);
  const addToast = useAppStore((s) => s.addToast);

  const fetchSettings = useCallback(async () => {
    try {
      const res = await api.getSettings();
      setSettings(res.data);
    } catch (err) {
      console.error('Failed to fetch settings:', err);
    }
  }, [setSettings]);

  useEffect(() => {
    fetchSettings();
  }, [fetchSettings]);

  const update = useCallback(
    async (updates: Partial<Settings>) => {
      try {
        const res = await api.updateSettings(updates);
        setSettings(res.data);
        addToast({ type: 'success', message: 'Settings saved' });
      } catch (err) {
        addToast({ type: 'error', message: `Failed to save settings: ${err instanceof Error ? err.message : 'Unknown error'}` });
        throw err;
      }
    },
    [setSettings, addToast]
  );

  return { settings, fetchSettings, update };
}
