import { Tray, Menu, shell, app } from 'electron';
import { showMainWindow, getMainWindow } from './windows.js';
import { randomUUID } from 'node:crypto';
import http from 'node:http';
import { loadTrayIcon } from './icons.js';

let tray: Tray | null = null;
const DAEMON_BASE = 'http://127.0.0.1:4777';

async function shutdownLanternRuntime(): Promise<void> {
  await new Promise<void>((resolve) => {
    const req = http.request(
      `${DAEMON_BASE}/api/system/shutdown`,
      {
        method: 'POST',
        timeout: 4000,
        headers: {
          Accept: 'application/json',
        },
      },
      (res) => {
        res.resume();
        resolve();
      }
    );

    req.on('error', () => resolve());
    req.on('timeout', () => {
      req.destroy();
      resolve();
    });
    req.end();
  });
}

export function createTray(): Tray {
  const icon = loadTrayIcon();

  tray = new Tray(icon);
  tray.setToolTip('Lantern — Dev Environment Manager');

  updateTrayMenu([], []);

  tray.on('click', () => {
    showMainWindow();
  });

  return tray;
}

function sendTrayAction(
  type: 'project:start' | 'project:stop' | 'service:start' | 'service:stop',
  name: string
): void {
  const win = getMainWindow();
  if (win && !win.isDestroyed()) {
    win.webContents.send('tray:action', {
      actionId: randomUUID(),
      type,
      name,
    });
  }
}

export function updateTrayMenu(
  projects: Array<{ name: string; domain: string; status: string }>,
  services: Array<{ name: string; status: string }>
): void {
  if (!tray) return;

  const projectItems: Electron.MenuItemConstructorOptions[] =
    projects.length > 0
      ? projects.map((p) => ({
          label: `${p.name} (${p.status})`,
          submenu: [
            {
              label: `Open https://${p.domain}`,
              click: () => shell.openExternal(`https://${p.domain}`),
              enabled: p.status === 'running',
            },
            {
              label: p.status === 'running' ? 'Stop' : 'Start',
              click: () => {
                sendTrayAction(
                  p.status === 'running' ? 'project:stop' : 'project:start',
                  p.name
                );
              },
            },
          ],
        }))
      : [{ label: 'No projects detected', enabled: false }];

  const serviceItems: Electron.MenuItemConstructorOptions[] =
    services.length > 0
      ? services.map((s) => ({
          label: s.name,
          type: 'checkbox' as const,
          checked: s.status === 'running',
          click: () => {
            sendTrayAction(
              s.status === 'running' ? 'service:stop' : 'service:start',
              s.name
            );
          },
        }))
      : [{ label: 'No services available', enabled: false }];

  const menu = Menu.buildFromTemplate([
    { label: 'Open Dashboard', click: () => showMainWindow() },
    { type: 'separator' },
    { label: 'Projects', submenu: projectItems },
    { type: 'separator' },
    { label: 'Services', submenu: serviceItems },
    { type: 'separator' },
    {
      label: 'Quit Lantern',
      click: async () => {
        await shutdownLanternRuntime();
        tray?.destroy();
        app.exit(0);
      },
    },
  ]);

  tray.setContextMenu(menu);
}
