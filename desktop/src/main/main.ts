import { app, BrowserWindow } from 'electron';
import { createTray } from './tray.js';
import { createMainWindow, getMainWindow } from './windows.js';
import { startDaemonWatcher } from './daemon.js';
import { startTrayRefresh } from './ipc.js';

// Enforce single instance
const gotLock = app.requestSingleInstanceLock();

if (!gotLock) {
  app.quit();
} else {
  app.on('second-instance', () => {
    const win = getMainWindow();
    if (win) {
      if (win.isMinimized()) win.restore();
      win.focus();
    }
  });

  app.whenReady().then(() => {
    createMainWindow();
    createTray();
    startDaemonWatcher();
    startTrayRefresh();
  });

  // Hide to tray instead of quitting on window close (Linux)
  app.on('window-all-closed', () => {
    // Don't quit — keep running in tray
  });

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createMainWindow();
    }
  });
}
