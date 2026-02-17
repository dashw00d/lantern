import { useState, useEffect } from 'react';
import { Plus, X, Save, RotateCw } from 'lucide-react';
import { useSettings } from '../hooks/useSettings';
import { useAppStore } from '../stores/appStore';
import { api } from '../api/client';
import { getLanternBridge, isElectronRuntime } from '../lib/electron';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { Select } from '../components/ui/Select';
import { FormField } from '../components/ui/FormField';
import { Card } from '../components/ui/Card';

export function Settings() {
  const { settings, update } = useSettings();
  const addToast = useAppStore((s) => s.addToast);
  const setProjects = useAppStore((s) => s.setProjects);
  const [saving, setSaving] = useState(false);
  const [shuttingDown, setShuttingDown] = useState(false);

  // Local form state
  const [tld, setTld] = useState(settings?.tld || '.glow');
  const [phpSocket, setPhpSocket] = useState(
    settings?.php_fpm_socket || '/run/php/php8.3-fpm.sock'
  );
  const [caddyMode, setCaddyMode] = useState(
    settings?.caddy_mode || 'files'
  );
  const [workspaceRoots, setWorkspaceRoots] = useState<string[]>(
    settings?.workspace_roots || ['~/sites']
  );
  const [newRoot, setNewRoot] = useState('');
  const [browsingRoot, setBrowsingRoot] = useState(false);

  // Sync local form state when server settings load
  useEffect(() => {
    if (settings) {
      setTld(settings.tld);
      setPhpSocket(settings.php_fpm_socket);
      setCaddyMode(settings.caddy_mode);
      setWorkspaceRoots(settings.workspace_roots);
    }
  }, [settings]);

  const appendRoot = (candidate: string): boolean => {
    const normalized = candidate.trim();
    if (!normalized || workspaceRoots.includes(normalized)) {
      return false;
    }

    setWorkspaceRoots([...workspaceRoots, normalized]);
    return true;
  };

  const addRoot = () => {
    if (appendRoot(newRoot)) {
      setNewRoot('');
    }
  };

  const removeRoot = (root: string) => {
    setWorkspaceRoots(workspaceRoots.filter((r) => r !== root));
  };

  const handleBrowseRoot = async () => {
    const bridge = getLanternBridge();

    if (!bridge) {
      addToast({
        type: 'warning',
        message: isElectronRuntime()
          ? 'Desktop bridge is unavailable. Restart Lantern and try again, or enter the path manually.'
          : 'Folder picker is only available in the desktop app. Enter the path manually.',
      });
      return;
    }

    setBrowsingRoot(true);
    try {
      const selected = await bridge.pickFolder();
      if (selected) {
        const wasAdded = appendRoot(selected);
        if (wasAdded) {
          setNewRoot('');
          addToast({ type: 'success', message: 'Workspace root added' });
        } else {
          setNewRoot(selected);
        }
      }
    } catch (err) {
      addToast({
        type: 'error',
        message: `Failed to open folder picker: ${err instanceof Error ? err.message : 'Unknown error'}`,
      });
    } finally {
      setBrowsingRoot(false);
    }
  };

  const handleSave = async () => {
    setSaving(true);
    try {
      await update({
        tld,
        php_fpm_socket: phpSocket,
        caddy_mode: caddyMode as 'files' | 'admin_api',
        workspace_roots: workspaceRoots,
      });
    } catch {
    } finally {
      setSaving(false);
    }
  };

  const handleShutdownAll = async () => {
    const confirmed = window.confirm(
      'Shutdown all Lantern runtime? This deactivates all projects and stops managed services.'
    );

    if (!confirmed) {
      return;
    }

    setShuttingDown(true);
    try {
      const res = await api.shutdownSystem();

      const projects = await api.listProjects({ includeHidden: true });
      setProjects(projects.data);

      if (res.data.status === 'ok') {
        addToast({
          type: 'success',
          message: 'Shutdown complete: all projects and managed services stopped.',
        });
      } else {
        addToast({
          type: 'warning',
          message: 'Shutdown partially completed. Check system status for details.',
        });
      }
    } catch (err) {
      addToast({
        type: 'error',
        message: `Shutdown failed: ${err instanceof Error ? err.message : 'Unknown error'}`,
      });
    } finally {
      setShuttingDown(false);
    }
  };

  if (!settings) {
    return (
      <div className="flex items-center justify-center h-64">
        <p className="text-muted-foreground">Loading settings...</p>
      </div>
    );
  }

  return (
    <div className="max-w-2xl space-y-6">
      {/* Workspace Roots */}
      <Card className="p-4">
        <h2 className="text-sm font-semibold mb-3">Workspace Roots</h2>
        <p className="text-xs text-muted-foreground mb-3">
          Directories where Lantern scans for projects.
        </p>
        <div className="space-y-2">
          {workspaceRoots.map((root) => (
            <div
              key={root}
              className="flex items-center justify-between rounded-md bg-muted px-3 py-2"
            >
              <span className="text-sm font-mono">{root}</span>
              <Button
                variant="ghost"
                size="icon"
                onClick={() => removeRoot(root)}
                aria-label={`Remove ${root}`}
                className="hover:text-destructive"
              >
                <X className="h-4 w-4" />
              </Button>
            </div>
          ))}
          <div className="flex items-center gap-2">
            <Input
              type="text"
              value={newRoot}
              onChange={(e) => setNewRoot(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && addRoot()}
              placeholder="/home/user/projects"
              className="flex-1 font-mono"
            />
            <Button
              variant="secondary"
              onClick={handleBrowseRoot}
              disabled={browsingRoot}
            >
              {browsingRoot ? 'Opening...' : 'Browse'}
            </Button>
            <Button variant="secondary" onClick={addRoot}>
              <Plus className="h-4 w-4" />
              Add
            </Button>
          </div>
        </div>
      </Card>

      {/* TLD */}
      <Card className="p-4">
        <h2 className="text-sm font-semibold mb-3">Domain Settings</h2>
        <div className="space-y-3">
          <FormField label="TLD" htmlFor="settings-tld">
            <Input
              id="settings-tld"
              type="text"
              value={tld}
              onChange={(e) => setTld(e.target.value)}
              className="font-mono"
            />
          </FormField>
        </div>
      </Card>

      {/* PHP-FPM */}
      <Card className="p-4">
        <h2 className="text-sm font-semibold mb-3">PHP Configuration</h2>
        <FormField label="PHP-FPM Socket Path" htmlFor="settings-php-socket">
          <Input
            id="settings-php-socket"
            type="text"
            value={phpSocket}
            onChange={(e) => setPhpSocket(e.target.value)}
            className="font-mono"
          />
        </FormField>
      </Card>

      {/* Caddy Mode */}
      <Card className="p-4">
        <h2 className="text-sm font-semibold mb-3">Caddy Integration</h2>
        <FormField label="Mode" htmlFor="settings-caddy-mode">
          <Select
            id="settings-caddy-mode"
            value={caddyMode}
            onChange={(e) => setCaddyMode(e.target.value as 'files' | 'admin_api')}
            className="w-full"
          >
            <option value="files">Config Files</option>
            <option value="admin_api">Admin API</option>
          </Select>
        </FormField>
      </Card>

      {/* Active Profile */}
      <Card className="p-4">
        <h2 className="text-sm font-semibold mb-3">Profile</h2>
        <p className="text-xs text-muted-foreground">
          Active profile: {settings.active_profile || 'None'}
        </p>
      </Card>

      {/* Save + runtime actions */}
      <div className="flex justify-between gap-3">
        <Button
          variant="destructive"
          onClick={handleShutdownAll}
          disabled={shuttingDown}
        >
          {shuttingDown ? 'Shutting Down...' : 'Shutdown All Runtime'}
        </Button>
        <Button onClick={handleSave} disabled={saving}>
          {saving ? (
            <RotateCw className="h-4 w-4 animate-spin" />
          ) : (
            <Save className="h-4 w-4" />
          )}
          Save Settings
        </Button>
      </div>

      {/* About */}
      <Card className="p-4">
        <h2 className="text-sm font-semibold mb-2">About</h2>
        <p className="text-xs text-muted-foreground">
          Lantern v0.1.0 — Local development environment manager
        </p>
      </Card>
    </div>
  );
}
