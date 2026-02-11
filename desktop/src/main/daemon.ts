import { Notification } from 'electron';
import http from 'node:http';
import { getMainWindow } from './windows.js';

const DAEMON_URL = 'http://127.0.0.1:4777/api/system/health';
const CHECK_INTERVAL = 10_000; // 10 seconds

let isConnected = false;
let watcherInterval: ReturnType<typeof setInterval> | null = null;

function checkDaemon(): Promise<boolean> {
  return new Promise((resolve) => {
    const req = http.get(DAEMON_URL, { timeout: 3000 }, (res) => {
      resolve(res.statusCode === 200);
    });
    req.on('error', () => resolve(false));
    req.on('timeout', () => {
      req.destroy();
      resolve(false);
    });
  });
}

function sendDaemonStatus(connected: boolean): void {
  const win = getMainWindow();
  if (win && !win.isDestroyed()) {
    win.webContents.send('daemon:status', connected);
  }
}

export function startDaemonWatcher(): void {
  // Check immediately
  checkDaemon().then((connected) => {
    isConnected = connected;
    sendDaemonStatus(connected);
    if (!connected) {
      new Notification({
        title: 'Lantern',
        body: 'Daemon is not running. Start it with: sudo systemctl start lantern',
      }).show();
    }
  });

  // Then check periodically
  watcherInterval = setInterval(async () => {
    const connected = await checkDaemon();

    if (connected && !isConnected) {
      new Notification({
        title: 'Lantern',
        body: 'Daemon connected',
      }).show();
    } else if (!connected && isConnected) {
      new Notification({
        title: 'Lantern',
        body: 'Daemon connection lost',
      }).show();
    }

    isConnected = connected;
    sendDaemonStatus(connected);
  }, CHECK_INTERVAL);
}

export function stopDaemonWatcher(): void {
  if (watcherInterval) {
    clearInterval(watcherInterval);
    watcherInterval = null;
  }
}

export function isDaemonConnected(): boolean {
  return isConnected;
}
