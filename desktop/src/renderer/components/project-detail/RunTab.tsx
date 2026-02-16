import { useEffect, useState } from 'react';
import { api } from '../../api/client';
import { useAppStore } from '../../stores/appStore';
import { Button } from '../ui/Button';
import { Input } from '../ui/Input';
import { Textarea } from '../ui/Textarea';
import { FormField } from '../ui/FormField';
import { Card, CardContent } from '../ui/Card';
import type { EditableTabProps } from './types';

export function RunTab({ project, onProjectUpdated }: EditableTabProps) {
  const addToast = useAppStore((s) => s.addToast);
  const [runCmdDraft, setRunCmdDraft] = useState(project.run_cmd || '');
  const [runCwdDraft, setRunCwdDraft] = useState(project.run_cwd || '.');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    setRunCmdDraft(project.run_cmd || '');
    setRunCwdDraft(project.run_cwd || '.');
  }, [project.name, project.run_cmd, project.run_cwd]);

  const currentRunCmd = project.run_cmd || '';
  const currentRunCwd = project.run_cwd || '.';
  const hasChanges =
    runCmdDraft !== currentRunCmd || runCwdDraft !== currentRunCwd;

  const handleSave = async () => {
    setSaving(true);

    try {
      const res = await api.updateProject(project.name, {
        run_cmd: runCmdDraft.trim() === '' ? null : runCmdDraft.trim(),
        run_cwd: runCwdDraft.trim() === '' ? '.' : runCwdDraft.trim(),
      });

      onProjectUpdated(res.data);
      addToast({
        type: 'success',
        message: 'Startup command saved. Use Restart to apply if currently running.',
      });
    } catch (err) {
      addToast({
        type: 'error',
        message: `Failed to save startup command: ${err instanceof Error ? err.message : 'Unknown error'}`,
      });
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="space-y-4">
      <Card>
        <CardContent>
          <h3 className="text-sm font-semibold mb-3">Run Configuration</h3>
          <p className="mb-4 text-xs text-muted-foreground">
            If set, Start/Restart will run this command and Stop will terminate it.
          </p>
          <div className="space-y-3 text-sm">
            <FormField label="Command" htmlFor="run-cmd">
              <Textarea
                id="run-cmd"
                value={runCmdDraft}
                onChange={(e) => setRunCmdDraft(e.target.value)}
                placeholder="npm run dev -- --port ${PORT}"
                className="h-24 resize-y font-mono text-xs"
              />
            </FormField>
            <FormField label="Working Directory" htmlFor="run-cwd">
              <Input
                id="run-cwd"
                value={runCwdDraft}
                onChange={(e) => setRunCwdDraft(e.target.value)}
                placeholder="."
                className="font-mono text-xs"
              />
            </FormField>
            {project.run_env && Object.keys(project.run_env).length > 0 && (
              <div>
                <span className="text-muted-foreground">Environment Variables</span>
                <div className="mt-1 space-y-1">
                  {Object.entries(project.run_env).map(([key, value]) => (
                    <div
                      key={key}
                      className="rounded-md bg-muted px-3 py-1.5 font-mono text-xs"
                    >
                      <span className="text-primary">{key}</span>=
                      <span>{value}</span>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
          <div className="mt-4 flex items-center justify-end gap-2">
            <Button
              variant="secondary"
              onClick={() => {
                setRunCmdDraft(currentRunCmd);
                setRunCwdDraft(currentRunCwd);
              }}
              disabled={!hasChanges || saving}
            >
              Reset
            </Button>
            <Button
              onClick={handleSave}
              disabled={!hasChanges || saving}
            >
              {saving ? 'Saving...' : 'Save'}
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
