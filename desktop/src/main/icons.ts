import { app, nativeImage } from 'electron';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

function loadFromCandidates(candidates: string[]): Electron.NativeImage {
  for (const candidate of candidates) {
    if (!candidate || !fs.existsSync(candidate)) continue;

    const image = nativeImage.createFromPath(candidate);
    if (!image.isEmpty()) return image;
  }

  return nativeImage.createEmpty();
}

export function loadAppIcon(): Electron.NativeImage {
  const appPath = app.getAppPath();

  return loadFromCandidates([
    path.join(appPath, 'resources', 'icon.png'),
    path.join(__dirname, '../../resources/icon.png'),
    path.join(process.resourcesPath, 'app.asar/resources/icon.png'),
    path.join(process.resourcesPath, 'resources/icon.png'),
    path.join(process.resourcesPath, 'icon.png'),
    '/usr/share/icons/hicolor/512x512/apps/lantern.png',
  ]);
}

export function loadTrayIcon(): Electron.NativeImage {
  const appPath = app.getAppPath();

  const trayIcon = loadFromCandidates([
    path.join(appPath, 'resources', 'tray-icon.png'),
    path.join(__dirname, '../../resources/tray-icon.png'),
    path.join(process.resourcesPath, 'app.asar/resources/tray-icon.png'),
    path.join(process.resourcesPath, 'resources/tray-icon.png'),
    path.join(process.resourcesPath, 'tray-icon.png'),
  ]);

  if (!trayIcon.isEmpty()) return trayIcon;

  const appIcon = loadAppIcon();
  if (appIcon.isEmpty()) return appIcon;

  return appIcon.resize({ width: 22, height: 22 });
}
