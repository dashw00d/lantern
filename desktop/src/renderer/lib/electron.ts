export interface TrayAction {
  actionId: string;
  type: 'project:start' | 'project:stop' | 'service:start' | 'service:stop';
  name: string;
}

export interface LanternBridge {
  onDaemonStatus(cb: (connected: boolean) => void): () => void;
  onTrayAction(cb: (action: TrayAction) => void): () => void;
  sendTrayActionResult(actionId: string, success: boolean, error?: string): void;
  requestTrayRefresh(): void;
  pickFolder(): Promise<string | null>;
}

declare global {
  interface Window {
    lantern?: LanternBridge;
  }
}

function isBridge(value: unknown): value is LanternBridge {
  if (!value || typeof value !== 'object') {
    return false;
  }

  const candidate = value as Partial<LanternBridge>;

  return (
    typeof candidate.onDaemonStatus === 'function' &&
    typeof candidate.onTrayAction === 'function' &&
    typeof candidate.sendTrayActionResult === 'function' &&
    typeof candidate.requestTrayRefresh === 'function'
  );
}

/** Returns the Electron IPC bridge, or null when running in a browser (vite dev). */
export function getLanternBridge(): LanternBridge | null {
  if (!isBridge(window.lantern)) {
    return null;
  }

  const candidate = window.lantern as Partial<LanternBridge>;

  if (typeof candidate.pickFolder === 'function') {
    return candidate as LanternBridge;
  }

  return {
    ...candidate,
    pickFolder: async () => {
      throw new Error(
        'Folder picker is not available in this desktop build. Restart Lantern after updating.'
      );
    },
  } as LanternBridge;
}

export function isElectronRuntime(): boolean {
  return navigator.userAgent.includes('Electron');
}
