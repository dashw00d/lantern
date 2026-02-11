import { ipcMain } from 'electron';
import http from 'node:http';
import { updateTrayMenu } from './tray.js';
import { getMainWindow } from './windows.js';

const DAEMON_BASE = 'http://127.0.0.1:4777';
const POLL_INTERVAL = 10_000;

interface TrayProject {
  name: string;
  domain: string;
  status: string;
}

interface TrayService {
  name: string;
  status: string;
}

function httpGet<T>(path: string): Promise<T | null> {
  return new Promise((resolve) => {
    const req = http.get(`${DAEMON_BASE}${path}`, { timeout: 3000 }, (res) => {
      let body = '';
      res.on('data', (chunk: Buffer) => {
        body += chunk.toString();
      });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body) as { data: T };
          resolve(parsed.data);
        } catch {
          resolve(null);
        }
      });
    });
    req.on('error', () => resolve(null));
    req.on('timeout', () => {
      req.destroy();
      resolve(null);
    });
  });
}

async function refreshTray(): Promise<void> {
  const [projects, services] = await Promise.all([
    httpGet<TrayProject[]>('/api/projects'),
    httpGet<TrayService[]>('/api/services'),
  ]);
  updateTrayMenu(projects ?? [], services ?? []);
}

let pollInterval: ReturnType<typeof setInterval> | null = null;

export function startTrayRefresh(): void {
  // Initial populate
  refreshTray();

  // Poll periodically
  pollInterval = setInterval(refreshTray, POLL_INTERVAL);

  // Renderer reports an action completed — refresh immediately
  ipcMain.on('tray:action-result', (_event, payload: { success: boolean }) => {
    if (payload.success) {
      refreshTray();
    }
  });

  // Renderer explicitly requests a refresh (after UI-initiated actions)
  ipcMain.on('tray:refresh', () => {
    refreshTray();
  });
}

export function stopTrayRefresh(): void {
  if (pollInterval) {
    clearInterval(pollInterval);
    pollInterval = null;
  }
}
