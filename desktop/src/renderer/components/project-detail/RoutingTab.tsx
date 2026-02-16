import { useEffect, useState } from 'react';
import { api } from '../../api/client';
import { useAppStore } from '../../stores/appStore';
import { Button } from '../ui/Button';
import { Input } from '../ui/Input';
import { Textarea } from '../ui/Textarea';
import { FormField } from '../ui/FormField';
import { Card, CardContent } from '../ui/Card';
import type { Project } from '../../types';
import type { EditableTabProps } from './types';

export function RoutingTab({ project, onProjectUpdated }: EditableTabProps) {
  const addToast = useAppStore((s) => s.addToast);
  const [domainDraft, setDomainDraft] = useState(project.domain || '');
  const [tagsDraft, setTagsDraft] = useState((project.tags || []).join(', '));
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    setDomainDraft(project.domain || '');
    setTagsDraft((project.tags || []).join(', '));
  }, [project.name, project.domain, project.tags]);

  const currentDomain = project.domain || '';
  const currentTags = (project.tags || []).join(', ');
  const hasChanges = domainDraft !== currentDomain || tagsDraft !== currentTags;

  const handleSave = async () => {
    setSaving(true);
    try {
      const normalizedTags = tagsDraft
        .split(/[\n,]/)
        .map((value) => value.trim())
        .filter((value) => value.length > 0);

      const res = await api.updateProject(project.name, {
        domain: domainDraft.trim() || null,
        tags: normalizedTags,
      } as Partial<Project>);
      onProjectUpdated(res.data);
      addToast({
        type: 'success',
        message: 'Routing metadata updated. Restart the project to apply domain changes.',
      });
    } catch (err) {
      addToast({
        type: 'error',
        message: `Failed to update routing metadata: ${err instanceof Error ? err.message : 'Unknown error'}`,
      });
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="space-y-4">
      <Card>
        <CardContent>
          <h3 className="text-sm font-semibold mb-3">Routing</h3>
          <div className="space-y-3 text-sm">
            <FormField label="Domain" htmlFor="routing-domain">
              <Input
                id="routing-domain"
                value={domainDraft}
                onChange={(e) => setDomainDraft(e.target.value)}
                placeholder="myproject.glow"
                className="font-mono text-xs"
              />
            </FormField>
            {project.port && (
              <div className="flex justify-between">
                <span className="text-muted-foreground">Upstream Port</span>
                <span className="font-mono text-xs">{project.port}</span>
              </div>
            )}
            <FormField label="Tags" htmlFor="routing-tags">
              <Textarea
                id="routing-tags"
                value={tagsDraft}
                onChange={(e) => setTagsDraft(e.target.value)}
                placeholder="tooling, internal, docs"
                className="h-20 font-mono text-xs"
              />
            </FormField>
          </div>
          <div className="mt-4 flex items-center justify-end gap-2">
            <Button
              variant="secondary"
              onClick={() => {
                setDomainDraft(currentDomain);
                setTagsDraft(currentTags);
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
