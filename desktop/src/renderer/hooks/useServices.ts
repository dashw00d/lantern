import { useEffect, useCallback } from 'react';
import { useAppStore } from '../stores/appStore';
import { api } from '../api/client';
import { joinChannel } from '../api/socket';
import { getLanternBridge } from '../lib/electron';
import type { Service } from '../types';

export function useServices() {
  const services = useAppStore((s) => s.services);
  const setServices = useAppStore((s) => s.setServices);
  const updateService = useAppStore((s) => s.updateService);
  const addToast = useAppStore((s) => s.addToast);

  const fetchServices = useCallback(async () => {
    try {
      const res = await api.listServices();
      setServices(res.data);
    } catch (err) {
      console.error('Failed to fetch services:', err);
    }
  }, [setServices]);

  useEffect(() => {
    fetchServices();
  }, [fetchServices]);

  const start = useCallback(
    async (name: string) => {
      try {
        const res = await api.startService(name);
        updateService(name, res.data);
        addToast({ type: 'success', message: `Service "${name}" started` });
        getLanternBridge()?.requestTrayRefresh();
      } catch (err) {
        addToast({ type: 'error', message: `Failed to start "${name}": ${err instanceof Error ? err.message : 'Unknown error'}` });
        throw err;
      }
    },
    [updateService, addToast]
  );

  const stop = useCallback(
    async (name: string) => {
      try {
        const res = await api.stopService(name);
        updateService(name, res.data);
        addToast({ type: 'success', message: `Service "${name}" stopped` });
        getLanternBridge()?.requestTrayRefresh();
      } catch (err) {
        addToast({ type: 'error', message: `Failed to stop "${name}": ${err instanceof Error ? err.message : 'Unknown error'}` });
        throw err;
      }
    },
    [updateService, addToast]
  );

  return { services, fetchServices, start, stop };
}

export function useServiceChannel() {
  const updateService = useAppStore((s) => s.updateService);

  useEffect(() => {
    const channel = joinChannel('services:lobby');

    channel.on('service_updated', (payload: { service: Service }) => {
      updateService(payload.service.name, payload.service);
    });

    return () => {};
  }, [updateService]);
}
