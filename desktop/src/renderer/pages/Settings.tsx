import { useState } from 'react';
import { Plus, X, Save, RotateCw } from 'lucide-react';
import { useSettings } from '../hooks/useSettings';

export function Settings() {
  const { settings, update } = useSettings();
  const [saving, setSaving] = useState(false);

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

  // Sync from server when settings load
  if (settings && tld === '.glow' && settings.tld !== '.glow') {
    setTld(settings.tld);
    setPhpSocket(settings.php_fpm_socket);
    setCaddyMode(settings.caddy_mode);
    setWorkspaceRoots(settings.workspace_roots);
  }

  const addRoot = () => {
    if (newRoot && !workspaceRoots.includes(newRoot)) {
      setWorkspaceRoots([...workspaceRoots, newRoot]);
      setNewRoot('');
    }
  };

  const removeRoot = (root: string) => {
    setWorkspaceRoots(workspaceRoots.filter((r) => r !== root));
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
    } finally {
      setSaving(false);
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
      <section className="rounded-lg border border-border bg-card p-4">
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
              <button
                onClick={() => removeRoot(root)}
                className="text-muted-foreground hover:text-destructive"
              >
                <X className="h-4 w-4" />
              </button>
            </div>
          ))}
          <div className="flex items-center gap-2">
            <input
              type="text"
              value={newRoot}
              onChange={(e) => setNewRoot(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && addRoot()}
              placeholder="/home/user/projects"
              className="h-9 flex-1 rounded-md border border-input bg-background px-3 text-sm font-mono placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring"
            />
            <button
              onClick={addRoot}
              className="inline-flex h-9 items-center gap-1.5 rounded-md border border-input bg-background px-3 text-sm hover:bg-accent"
            >
              <Plus className="h-4 w-4" />
              Add
            </button>
          </div>
        </div>
      </section>

      {/* TLD */}
      <section className="rounded-lg border border-border bg-card p-4">
        <h2 className="text-sm font-semibold mb-3">Domain Settings</h2>
        <div className="space-y-3">
          <div>
            <label className="text-xs text-muted-foreground">TLD</label>
            <input
              type="text"
              value={tld}
              onChange={(e) => setTld(e.target.value)}
              className="mt-1 h-9 w-full rounded-md border border-input bg-background px-3 text-sm font-mono focus:outline-none focus:ring-2 focus:ring-ring"
            />
          </div>
        </div>
      </section>

      {/* PHP-FPM */}
      <section className="rounded-lg border border-border bg-card p-4">
        <h2 className="text-sm font-semibold mb-3">PHP Configuration</h2>
        <div>
          <label className="text-xs text-muted-foreground">
            PHP-FPM Socket Path
          </label>
          <input
            type="text"
            value={phpSocket}
            onChange={(e) => setPhpSocket(e.target.value)}
            className="mt-1 h-9 w-full rounded-md border border-input bg-background px-3 text-sm font-mono focus:outline-none focus:ring-2 focus:ring-ring"
          />
        </div>
      </section>

      {/* Caddy Mode */}
      <section className="rounded-lg border border-border bg-card p-4">
        <h2 className="text-sm font-semibold mb-3">Caddy Integration</h2>
        <div>
          <label className="text-xs text-muted-foreground">Mode</label>
          <select
            value={caddyMode}
            onChange={(e) => setCaddyMode(e.target.value as 'files' | 'admin_api')}
            className="mt-1 h-9 w-full rounded-md border border-input bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-ring"
          >
            <option value="files">Config Files</option>
            <option value="admin_api">Admin API</option>
          </select>
        </div>
      </section>

      {/* Active Profile */}
      <section className="rounded-lg border border-border bg-card p-4">
        <h2 className="text-sm font-semibold mb-3">Profile</h2>
        <p className="text-xs text-muted-foreground">
          Active profile: {settings.active_profile || 'None'}
        </p>
      </section>

      {/* Save button */}
      <div className="flex justify-end">
        <button
          onClick={handleSave}
          disabled={saving}
          className="inline-flex items-center gap-2 rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:bg-primary/90 disabled:opacity-50"
        >
          {saving ? (
            <RotateCw className="h-4 w-4 animate-spin" />
          ) : (
            <Save className="h-4 w-4" />
          )}
          Save Settings
        </button>
      </div>

      {/* About */}
      <section className="rounded-lg border border-border bg-card p-4">
        <h2 className="text-sm font-semibold mb-2">About</h2>
        <p className="text-xs text-muted-foreground">
          Lantern v0.1.0 — Local development environment manager
        </p>
      </section>
    </div>
  );
}
