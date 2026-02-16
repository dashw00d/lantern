import { useEffect, useState } from 'react';
import { FileText } from 'lucide-react';
import { cn } from '../../lib/utils';
import { api } from '../../api/client';
import { useAppStore } from '../../stores/appStore';
import { Button } from '../ui/Button';
import { Textarea } from '../ui/Textarea';
import { FormField } from '../ui/FormField';
import { Card, CardContent } from '../ui/Card';
import type { DocEntry } from '../../types';
import type { EditableTabProps } from './types';

export function DocsTab({ project, onProjectUpdated }: EditableTabProps) {
  const addToast = useAppStore((s) => s.addToast);
  const [docs, setDocs] = useState<DocEntry[]>(project.docs_available || project.docs || []);
  const [selectedDoc, setSelectedDoc] = useState<string | null>(null);
  const [docContent, setDocContent] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [docsDraft, setDocsDraft] = useState(
    (project.docs || []).map((doc) => doc.path).join('\n')
  );

  useEffect(() => {
    api.listDocs(project.name).then((res) => setDocs(res.data)).catch((err) => console.warn('Failed to load docs list:', err));
  }, [project.name]);

  useEffect(() => {
    setDocsDraft((project.docs || []).map((doc) => doc.path).join('\n'));
  }, [project.docs, project.name]);

  const loadDoc = async (path: string) => {
    setSelectedDoc(path);
    setLoading(true);
    try {
      const content = await api.getDoc(project.name, path);
      setDocContent(content);
    } catch {
      setDocContent('Failed to load document');
    } finally {
      setLoading(false);
    }
  };

  const handleSaveDocs = async () => {
    setSaving(true);
    try {
      const nextDocs = docsDraft
        .split(/\r?\n/)
        .map((value) => value.trim())
        .filter((value) => value.length > 0);

      const res = await api.patchProject(project.name, {
        docs: nextDocs.map((path) => ({ path, kind: 'markdown' })),
      });
      onProjectUpdated(res.data);
      const refreshed = await api.listDocs(res.data.name);
      setDocs(refreshed.data);
      addToast({ type: 'success', message: 'Docs updated' });
    } catch (err) {
      addToast({
        type: 'error',
        message: `Failed to update docs: ${err instanceof Error ? err.message : 'Unknown error'}`,
      });
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="space-y-4">
      <Card>
        <CardContent>
          <h3 className="mb-2 text-sm font-semibold">Edit Docs List</h3>
          <p className="mb-3 text-xs text-muted-foreground">
            One relative path per line. This updates the project metadata directly.
          </p>
          <FormField label="Document paths" htmlFor="docs-paths">
            <Textarea
              id="docs-paths"
              value={docsDraft}
              onChange={(e) => setDocsDraft(e.target.value)}
              placeholder={'README.md\ndocs/API.md'}
              className="h-24"
            />
          </FormField>
          <div className="mt-3 flex justify-end">
            <Button
              onClick={handleSaveDocs}
              disabled={saving}
            >
              {saving ? 'Saving...' : 'Save Docs'}
            </Button>
          </div>
        </CardContent>
      </Card>
      <div className="grid grid-cols-4 gap-4">
        <Card>
          <CardContent>
            <h3 className="text-sm font-semibold mb-3 flex items-center gap-2">
              <FileText className="h-4 w-4" />
              Documents
            </h3>
            <div className="space-y-1">
              {docs.map((doc) => (
                <button
                  key={doc.path}
                  onClick={() => loadDoc(doc.path)}
                  aria-label={`View document: ${doc.path}`}
                  className={cn(
                    'w-full text-left rounded-md px-3 py-2 text-sm',
                    selectedDoc === doc.path
                      ? 'bg-primary/10 text-primary'
                      : 'hover:bg-accent text-muted-foreground'
                  )}
                >
                  <div className="font-mono text-xs">{doc.path}</div>
                  <div className="text-xs text-muted-foreground mt-0.5">
                    {doc.kind}
                    {doc.source ? ` • ${doc.source}` : ''}
                    {doc.size ? ` • ${(doc.size / 1024).toFixed(1)}KB` : ''}
                  </div>
                </button>
              ))}
            </div>
          </CardContent>
        </Card>
        <Card className="col-span-3">
          <CardContent>
            {selectedDoc ? (
              loading ? (
                <p className="text-muted-foreground text-sm">Loading...</p>
              ) : (
                <pre className="text-sm whitespace-pre-wrap font-mono overflow-auto max-h-[600px]">
                  {docContent}
                </pre>
              )
            ) : (
              <p className="text-muted-foreground text-sm">Select a document to view</p>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
