import { useEffect, useCallback } from 'react';
import { useAppStore } from '../stores/appStore';
import { api } from '../api/client';
import { joinChannel } from '../api/socket';
import type { HealthStatus } from '../types';

export function useHealth() {
  const health = useAppStore((s) => s.health);
  const setHealth = useAppStore((s) => s.setHealth);
  const daemonConnected = useAppStore((s) => s.daemonConnected);

  const fetchHealth = useCallback(async () => {
    try {
      const res = await api.getHealth();
      setHealth(res.data);
      useAppStore.getState().setDaemonConnected(true);
    } catch (err) {
      useAppStore.getState().setDaemonConnected(false);
    }
  }, [setHealth]);

  useEffect(() => {
    fetchHealth();
    const interval = setInterval(fetchHealth, 15_000);
    return () => clearInterval(interval);
  }, [fetchHealth]);

  return { health, daemonConnected, fetchHealth };
}

export function useHealthChannel() {
  const setHealth = useAppStore((s) => s.setHealth);
  const setDaemonConnected = useAppStore((s) => s.setDaemonConnected);

  useEffect(() => {
    try {
      const channel = joinChannel('system:health');

      channel.on('health_update', (payload: HealthStatus) => {
        setHealth(payload);
        setDaemonConnected(true);
      });
    } catch {
      setDaemonConnected(false);
    }

    return () => {};
  }, [setHealth, setDaemonConnected]);
}
