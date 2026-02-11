import { useEffect } from 'react';
import { useAppStore } from '../stores/appStore';
import { getLanternBridge } from '../lib/electron';
import { api } from '../api/client';

export function useElectronBridge() {
  const setDaemonConnected = useAppStore((s) => s.setDaemonConnected);
  const addToast = useAppStore((s) => s.addToast);
  const updateProject = useAppStore((s) => s.updateProject);
  const updateService = useAppStore((s) => s.updateService);

  useEffect(() => {
    const bridge = getLanternBridge();
    if (!bridge) return;

    const unsubDaemon = bridge.onDaemonStatus((connected) => {
      setDaemonConnected(connected);
    });

    const unsubTray = bridge.onTrayAction(async (action) => {
      try {
        switch (action.type) {
          case 'project:start': {
            updateProject(action.name, { status: 'starting' });
            const res = await api.activateProject(action.name);
            updateProject(action.name, res.data);
            addToast({ type: 'success', message: `Project "${action.name}" started` });
            break;
          }
          case 'project:stop': {
            updateProject(action.name, { status: 'stopping' });
            const res = await api.deactivateProject(action.name);
            updateProject(action.name, res.data);
            addToast({ type: 'success', message: `Project "${action.name}" stopped` });
            break;
          }
          case 'service:start': {
            const res = await api.startService(action.name);
            updateService(action.name, res.data);
            addToast({ type: 'success', message: `Service "${action.name}" started` });
            break;
          }
          case 'service:stop': {
            const res = await api.stopService(action.name);
            updateService(action.name, res.data);
            addToast({ type: 'success', message: `Service "${action.name}" stopped` });
            break;
          }
        }
        bridge.sendTrayActionResult(action.actionId, true);
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Unknown error';
        addToast({ type: 'error', message: `Failed to ${action.type.replace(':', ' ')}: ${message}` });
        bridge.sendTrayActionResult(action.actionId, false, message);
      }
    });

    return () => {
      unsubDaemon();
      unsubTray();
    };
  }, [setDaemonConnected, addToast, updateProject, updateService]);
}
