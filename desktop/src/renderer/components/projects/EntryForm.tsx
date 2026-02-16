import { useState } from 'react';
import { useAppStore } from '../../stores/appStore';
import { getLanternBridge, isElectronRuntime } from '../../lib/electron';
import type { EntryCategory, EntryMode } from '../../lib/project-helpers';
import { Button } from '../ui/Button';
import { Input } from '../ui/Input';
import { Textarea } from '../ui/Textarea';
import { Select } from '../ui/Select';
import { FormField } from '../ui/FormField';

export interface EntryFormValues {
  name: string;
  mode: EntryMode;
  path: string;
  remote_url: string;
  category: EntryCategory;
  docs_only: boolean;
  tags: string;
  domain: string;
  run_cmd: string;
  docs: string;
}

interface EntryFormProps {
  initialValues?: Partial<EntryFormValues>;
  onSubmit: (values: EntryFormValues) => Promise<void>;
  onCancel?: () => void;
  submitLabel?: string;
  mode: 'create' | 'edit';
  showBrowse?: boolean;
}

const DEFAULTS: EntryFormValues = {
  name: '',
  mode: 'local',
  path: '.',
  remote_url: '',
  category: 'tool',
  docs_only: false,
  tags: '',
  domain: '',
  run_cmd: '',
  docs: '',
};

export function EntryForm({
  initialValues,
  onSubmit,
  onCancel,
  submitLabel = 'Save',
  mode,
  showBrowse = true,
}: EntryFormProps) {
  const addToast = useAppStore((s) => s.addToast);
  const [form, setForm] = useState<EntryFormValues>({
    ...DEFAULTS,
    ...initialValues,
  });
  const [submitting, setSubmitting] = useState(false);

  const set = <K extends keyof EntryFormValues>(key: K, value: EntryFormValues[K]) =>
    setForm((prev) => ({ ...prev, [key]: value }));

  const handleBrowsePath = async () => {
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

    try {
      const selected = await bridge.pickFolder();
      if (selected) {
        set('path', selected);
      }
    } catch (err) {
      addToast({
        type: 'error',
        message: `Failed to open folder picker: ${err instanceof Error ? err.message : 'Unknown error'}`,
      });
    }
  };

  const handleSubmit = async () => {
    if (!form.name.trim()) {
      addToast({ type: 'error', message: 'Name is required.' });
      return;
    }

    if (form.mode === 'local' && !form.path.trim()) {
      addToast({ type: 'error', message: 'Local folder path is required.' });
      return;
    }

    if (form.mode === 'remote' && !form.remote_url.trim()) {
      addToast({ type: 'error', message: 'Remote URL is required.' });
      return;
    }

    setSubmitting(true);
    try {
      await onSubmit(form);
    } finally {
      setSubmitting(false);
    }
  };

  const prefix = mode === 'create' ? 'create' : 'edit';

  return (
    <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
      <FormField label="Name" htmlFor={`${prefix}-name`}>
        <Input
          id={`${prefix}-name`}
          value={form.name}
          onChange={(e) => set('name', e.target.value)}
        />
      </FormField>

      <FormField label="Category" htmlFor={`${prefix}-category`}>
        <Select
          id={`${prefix}-category`}
          value={form.category}
          onChange={(e) => set('category', e.target.value as EntryCategory)}
          className="w-full"
        >
          <option value="tool">Tool</option>
          <option value="site">Site</option>
          <option value="api">API</option>
          <option value="project">Project</option>
        </Select>
      </FormField>

      <div className="space-y-1 text-sm md:col-span-2">
        <span>Source</span>
        <div className="flex items-center gap-2">
          <Button
            variant={form.mode === 'local' ? 'primary' : 'secondary'}
            onClick={() => set('mode', 'local')}
          >
            Local folder
          </Button>
          <Button
            variant={form.mode === 'remote' ? 'primary' : 'secondary'}
            onClick={() => {
              setForm((prev) => ({ ...prev, mode: 'remote', docs_only: false }));
            }}
          >
            Remote URL
          </Button>
        </div>
      </div>

      {form.mode === 'local' && (
        <div className="space-y-1 text-sm md:col-span-2">
          <span>Template</span>
          <label className="inline-flex h-9 items-center gap-2 rounded-md border border-input px-3">
            <input
              type="checkbox"
              checked={form.docs_only}
              onChange={(e) => set('docs_only', e.target.checked)}
            />
            Docs-only entry {mode === 'create' && '(folder + docs metadata, no run command)'}
          </label>
        </div>
      )}

      {form.mode === 'local' ? (
        <FormField label="Folder path" htmlFor={`${prefix}-path`} className="md:col-span-2">
          <div className="flex items-center gap-2">
            <Input
              id={`${prefix}-path`}
              value={form.path}
              onChange={(e) => set('path', e.target.value)}
            />
            {showBrowse && (
              <Button variant="secondary" onClick={handleBrowsePath}>
                Browse
              </Button>
            )}
          </div>
        </FormField>
      ) : (
        <FormField label="Remote URL" htmlFor={`${prefix}-remote-url`} className="md:col-span-2">
          <Input
            id={`${prefix}-remote-url`}
            value={form.remote_url}
            onChange={(e) => set('remote_url', e.target.value)}
            placeholder="https://example.com"
          />
        </FormField>
      )}

      <FormField label="Domain (.glow alias, optional)" htmlFor={`${prefix}-domain`} className="md:col-span-2">
        <Input
          id={`${prefix}-domain`}
          value={form.domain}
          onChange={(e) => set('domain', e.target.value)}
          placeholder="my-tool.glow"
        />
      </FormField>

      <FormField label="Tags (comma or newline separated)" htmlFor={`${prefix}-tags`} className="md:col-span-2">
        <Textarea
          id={`${prefix}-tags`}
          value={form.tags}
          onChange={(e) => set('tags', e.target.value)}
          placeholder={'tooling, docs\ninternal'}
          className="h-16"
        />
      </FormField>

      {form.mode === 'local' && !form.docs_only && (
        <FormField label="Run command (optional)" htmlFor={`${prefix}-run-cmd`} className="md:col-span-2">
          <Input
            id={`${prefix}-run-cmd`}
            value={form.run_cmd}
            onChange={(e) => set('run_cmd', e.target.value)}
            placeholder="npm run dev -- --port ${PORT}"
          />
        </FormField>
      )}

      <FormField label="Docs (one relative path per line)" htmlFor={`${prefix}-docs`} className="md:col-span-2">
        <Textarea
          id={`${prefix}-docs`}
          value={form.docs}
          onChange={(e) => set('docs', e.target.value)}
          placeholder={'README.md\ndocs/API.md'}
          className="h-24"
        />
      </FormField>

      <div className="mt-1 flex items-center justify-end gap-2 md:col-span-2">
        {onCancel && (
          <Button variant="secondary" onClick={onCancel}>
            Cancel
          </Button>
        )}
        <Button
          onClick={handleSubmit}
          disabled={submitting || form.name.trim() === ''}
        >
          {submitting ? (mode === 'create' ? 'Adding...' : 'Saving...') : submitLabel}
        </Button>
      </div>
    </div>
  );
}
