import { contextBridge, ipcRenderer } from 'electron';

export interface TrayAction {
  actionId: string;
  type: 'project:start' | 'project:stop' | 'service:start' | 'service:stop';
  name: string;
}

contextBridge.exposeInMainWorld('lantern', {
  onDaemonStatus(cb: (connected: boolean) => void) {
    const handler = (_event: Electron.IpcRendererEvent, connected: boolean) =>
      cb(connected);
    ipcRenderer.on('daemon:status', handler);
    return () => {
      ipcRenderer.removeListener('daemon:status', handler);
    };
  },

  onTrayAction(cb: (action: TrayAction) => void) {
    const handler = (_event: Electron.IpcRendererEvent, action: TrayAction) =>
      cb(action);
    ipcRenderer.on('tray:action', handler);
    return () => {
      ipcRenderer.removeListener('tray:action', handler);
    };
  },

  sendTrayActionResult(actionId: string, success: boolean, error?: string) {
    ipcRenderer.send('tray:action-result', { actionId, success, error });
  },

  requestTrayRefresh() {
    ipcRenderer.send('tray:refresh');
  },

  pickFolder() {
    return ipcRenderer.invoke('dialog:pick-folder') as Promise<string | null>;
  },
});
