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

/** Returns the Electron IPC bridge, or null when running in a browser (vite dev). */
export function getLanternBridge(): LanternBridge | null {
  return window.lantern ?? null;
}
