import { useState } from 'react';
import { api } from '../../api/client';
import { useAppStore } from '../../stores/appStore';
import { categoryFromKind, kindFromCategory } from '../../lib/project-helpers';
import { Button } from '../ui/Button';
import { Card, CardContent } from '../ui/Card';
import { EntryForm } from '../projects/EntryForm';
import type { EntryFormValues } from '../projects/EntryForm';
import type { EditableTabProps } from './types';
import type { Project } from '../../types';

export function EntryTab({ project, onProjectUpdated }: EditableTabProps) {
  const addToast = useAppStore((s) => s.addToast);
  const [resetting, setResetting] = useState(false);

  const initialValues: Partial<EntryFormValues> = {
    name: project.name,
    category: categoryFromKind(project.kind),
    mode: project.upstream_url ? 'remote' : 'local',
    path: project.path || '.',
    remote_url: project.upstream_url || '',
    domain: project.domain || '',
    docs_only:
      !project.upstream_url &&
      (!project.run_cmd || project.run_cmd.trim() === '') &&
      project.type === 'unknown',
    run_cmd: project.run_cmd || '',
    docs: (project.docs || []).map((doc) => doc.path).join('\n'),
    tags: (project.tags || []).join(', '),
  };

  const handleSave = async (values: EntryFormValues) => {
    const docs = values.docs
      .split(/\r?\n/)
      .map((v) => v.trim())
      .filter((v) => v.length > 0);

    const tags = values.tags
      .split(/[\r\n,]/)
      .map((v) => v.trim())
      .filter((v) => v.length > 0);

    const updates: Partial<Project> & { new_name?: string } = {
      kind: kindFromCategory(values.category),
      path: values.mode === 'local' ? values.path.trim() : '.',
      upstream_url: values.mode === 'remote' ? values.remote_url.trim() : null,
      domain: values.domain.trim() || undefined,
      run_cmd:
        values.mode === 'local' && !values.docs_only
          ? values.run_cmd.trim() || null
          : null,
      docs: docs.map((path) => ({ path, kind: 'markdown' })),
      tags,
    };

    if (values.mode === 'remote') {
      updates.type = 'proxy';
    } else if (values.docs_only) {
      updates.type = 'unknown';
    } else if (
      values.run_cmd.trim() !== '' &&
      (project.type === 'unknown' || project.type == null)
    ) {
      updates.type = 'proxy';
    }

    const nextName = values.name.trim();
    if (nextName !== project.name) {
      updates.new_name = nextName;
    }

    try {
      const res = await api.patchProject(project.name, updates);
      onProjectUpdated(res.data);
      addToast({ type: 'success', message: 'Entry settings updated' });
    } catch (err) {
      addToast({
        type: 'error',
        message: `Failed to update entry settings: ${err instanceof Error ? err.message : 'Unknown error'}`,
      });
    }
  };

  const handleResetFromManifest = async () => {
    setResetting(true);

    try {
      const res = await api.resetProject(project.name);
      onProjectUpdated(res.data);
      addToast({
        type: 'success',
        message: 'Project reset from lantern.yaml manifest',
      });
    } catch (err) {
      addToast({
        type: 'error',
        message: `Failed to reset from manifest: ${err instanceof Error ? err.message : 'Unknown error'}`,
      });
    } finally {
      setResetting(false);
    }
  };

  return (
    <div className="space-y-4">
      <Card>
        <CardContent>
          <div className="mb-3 flex items-center justify-between gap-3">
            <h3 className="text-sm font-semibold">Entry Settings</h3>
            <Button
              variant="secondary"
              onClick={handleResetFromManifest}
              disabled={resetting}
            >
              {resetting ? 'Resetting...' : 'Reset From YAML'}
            </Button>
          </div>
          <p className="mb-4 text-xs text-muted-foreground">
            This mirrors the Add flow. You can edit identity, source, routing, docs, and tags here. Reset loads values from local lantern.yaml/lantern.yml without writing files.
          </p>
          <EntryForm
            key={project.name}
            initialValues={initialValues}
            onSubmit={handleSave}
            submitLabel="Save"
            mode="edit"
          />
        </CardContent>
      </Card>
    </div>
  );
}
