import { useEffect, useMemo, useState } from 'react';
import {
  LayoutGrid,
  List,
  RefreshCw,
  Play,
  Square,
  Plus,
  Eye,
  EyeOff,
  Trash2,
} from 'lucide-react';
import { cn } from '../lib/utils';
import { api } from '../api/client';
import { useProjects } from '../hooks/useProjects';
import { useAppStore } from '../stores/appStore';
import { ProjectCard } from '../components/projects/ProjectCard';
import { StatusBadge } from '../components/common/StatusBadge';
import { TypeBadge } from '../components/common/TypeBadge';
import { Modal } from '../components/ui/Modal';
import { Button } from '../components/ui/Button';
import { Select } from '../components/ui/Select';
import { ConfirmDialog } from '../components/ui/ConfirmDialog';
import { EntryForm } from '../components/projects/EntryForm';
import type { EntryFormValues } from '../components/projects/EntryForm';
import { Link } from 'react-router-dom';
import { Card } from '../components/ui/Card';
import { Skeleton } from '../components/ui/Skeleton';
import { categoryFromKind, kindFromCategory } from '../lib/project-helpers';
import type {
  Project,
  ProjectKind,
  ProjectStatus,
  ProjectType,
  ToolSummary,
} from '../types';

type FilterStatus = 'all' | ProjectStatus;
type FilterType = 'all' | ProjectType;
type CategoryFilter = 'all' | 'tool' | 'site' | 'api' | 'project';

const categoryButtons: { value: CategoryFilter; label: string }[] = [
  { value: 'all', label: 'All' },
  { value: 'tool', label: 'Tools' },
  { value: 'site', label: 'Sites' },
  { value: 'api', label: 'APIs' },
  { value: 'project', label: 'Projects' },
];

function categoryForProject(project: Project): CategoryFilter {
  return categoryFromKind(project.kind);
}

function categoryForTool(tool: ToolSummary): CategoryFilter {
  return categoryFromKind(tool.kind);
}

export function Projects() {
  const {
    projects,
    activate,
    deactivate,
    restart,
    scan,
    create,
    setHidden,
    setKind,
    remove,
    fetchProjects,
  } = useProjects();

  const addToast = useAppStore((s) => s.addToast);
  const viewMode = useAppStore((s) => s.projectViewMode);
  const setViewMode = useAppStore((s) => s.setProjectViewMode);

  const [statusFilter, setStatusFilter] = useState<FilterStatus>('all');
  const [typeFilter, setTypeFilter] = useState<FilterType>('all');
  const [categoryFilter, setCategoryFilter] = useState<CategoryFilter>('all');
  const [showHidden, setShowHidden] = useState(false);
  const [scanning, setScanning] = useState(false);
  const [showCreate, setShowCreate] = useState(false);
  const [availableTools, setAvailableTools] = useState<ToolSummary[]>([]);
  const [confirmDelete, setConfirmDelete] = useState<Project | null>(null);
  const projectsLoaded = useAppStore((s) => s.projectsLoaded);

  useEffect(() => {
    fetchProjects(showHidden);
  }, [fetchProjects, showHidden]);

  useEffect(() => {
    let cancelled = false;

    const loadTools = async () => {
      try {
        const kinds =
          categoryFilter === 'tool'
            ? ['tool']
            : categoryFilter === 'site'
              ? ['website']
              : categoryFilter === 'api'
                ? ['service', 'capability']
                : undefined;

        const res = await api.listTools({
          includeHidden: showHidden,
          kinds,
        });

        if (!cancelled) {
          setAvailableTools(res.data);
        }
      } catch (err) {
        if (!cancelled) {
          console.warn('Failed to load tools:', err);
          setAvailableTools([]);
        }
      }
    };

    loadTools();

    return () => {
      cancelled = true;
    };
  }, [showHidden, categoryFilter]);

  const toolsByName = useMemo(
    () => new Map(availableTools.map((tool) => [tool.name, tool])),
    [availableTools]
  );

  const filtered = useMemo(
    () => {
      const base = projects.filter((p) => {
        if (!showHidden && p.enabled === false) return false;
        if (statusFilter !== 'all' && p.status !== statusFilter) return false;
        if (typeFilter !== 'all' && p.type !== typeFilter) return false;
        if (categoryFilter !== 'all' && categoryForProject(p) !== categoryFilter) return false;
        return true;
      });

      if (categoryFilter === 'tool' || categoryFilter === 'site' || categoryFilter === 'api') {
        const names = new Set(
          availableTools
            .filter((tool) => categoryForTool(tool) === categoryFilter)
            .map((tool) => tool.name)
        );

        return base.filter((project) => names.has(project.name));
      }

      return base;
    },
    [projects, showHidden, statusFilter, typeFilter, categoryFilter, availableTools]
  );

  const handleScan = async () => {
    setScanning(true);
    try {
      await scan(showHidden);
    } finally {
      setScanning(false);
    }
  };

  const handleCreate = async (values: EntryFormValues) => {
    const docs = values.docs
      .split(/\r?\n/)
      .map((entry) => entry.trim())
      .filter((entry) => entry.length > 0);

    const tags = values.tags
      .split(/[\r\n,]/)
      .map((entry) => entry.trim())
      .filter((entry) => entry.length > 0);

    const inferredType: ProjectType =
      values.docs_only
        ? 'unknown'
        : values.mode === 'remote' || values.run_cmd.trim()
          ? 'proxy'
          : 'unknown';

    const payload: Partial<Project> & { name: string; path: string } = {
      name: values.name.trim(),
      path: values.mode === 'local' ? values.path.trim() : '.',
      kind: kindFromCategory(values.category),
      type: inferredType,
      tags: tags.length > 0 ? tags : undefined,
      domain: values.domain.trim() || undefined,
      upstream_url: values.mode === 'remote' ? values.remote_url.trim() : undefined,
      run_cmd:
        values.mode === 'local' && !values.docs_only
          ? values.run_cmd.trim() || undefined
          : undefined,
      docs: docs.length > 0 ? docs.map((path) => ({ path, kind: 'markdown' })) : undefined,
    };

    await create(payload, showHidden);
    setShowCreate(false);
  };

  const handleToggleHidden = async (project: Project) => {
    await setHidden(project.name, project.enabled !== false, showHidden);
  };

  const handleDelete = async (project: Project) => {
    setConfirmDelete(project);
  };

  const handleConfirmDelete = async () => {
    if (!confirmDelete) return;
    await remove(confirmDelete.name, showHidden);
    setConfirmDelete(null);
  };

  const handleKindChange = async (project: Project, nextKind: ProjectKind) => {
    if (project.kind === nextKind) return;
    await setKind(project.name, nextKind);
  };

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="flex flex-wrap items-center gap-2">
          <Select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value as FilterStatus)}
          >
            <option value="all">All Status</option>
            <option value="running">Running</option>
            <option value="stopped">Stopped</option>
            <option value="error">Error</option>
            <option value="needs_config">Needs Config</option>
          </Select>

          <Select
            value={typeFilter}
            onChange={(e) => setTypeFilter(e.target.value as FilterType)}
          >
            <option value="all">All Types</option>
            <option value="php">PHP</option>
            <option value="proxy">Proxy</option>
            <option value="static">Static</option>
            <option value="unknown">Unknown</option>
          </Select>

          <label className="inline-flex h-9 items-center gap-2 rounded-md border border-input px-3 text-sm">
            <input
              type="checkbox"
              checked={showHidden}
              onChange={(e) => setShowHidden(e.target.checked)}
            />
            Show hidden
          </label>
        </div>

        <div className="flex items-center gap-2">
          <Button variant="secondary" onClick={() => setShowCreate(true)}>
            <Plus className="h-4 w-4" />
            Add
          </Button>

          <Button
            variant="secondary"
            onClick={handleScan}
            disabled={scanning}
          >
            <RefreshCw className={cn('h-4 w-4', scanning && 'animate-spin')} />
            Scan
          </Button>

          <div className="flex rounded-md border border-input">
            <Button
              variant={viewMode === 'grid' ? 'secondary' : 'ghost'}
              size="icon"
              onClick={() => setViewMode('grid')}
              aria-label="Grid view"
              className="rounded-r-none border-0"
            >
              <LayoutGrid className="h-4 w-4" />
            </Button>
            <Button
              variant={viewMode === 'list' ? 'secondary' : 'ghost'}
              size="icon"
              onClick={() => setViewMode('list')}
              aria-label="List view"
              className="rounded-l-none border-l border-input border-y-0 border-r-0"
            >
              <List className="h-4 w-4" />
            </Button>
          </div>
        </div>
      </div>

      <div className="flex flex-wrap items-center gap-2">
        {categoryButtons.map((item) => (
          <Button
            key={item.value}
            variant={categoryFilter === item.value ? 'primary' : 'secondary'}
            size="sm"
            onClick={() => setCategoryFilter(item.value)}
          >
            {item.label}
          </Button>
        ))}
      </div>

      <p className="text-sm text-muted-foreground">
        {filtered.length} entr{filtered.length === 1 ? 'y' : 'ies'}
      </p>

      {!projectsLoaded ? (
        viewMode === 'grid' ? (
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {[1, 2, 3, 4, 5, 6].map((i) => (
              <Card key={i} className="p-4 space-y-3">
                <div className="flex items-center gap-3">
                  <Skeleton className="h-5 w-5 rounded" />
                  <Skeleton className="h-4 w-32" />
                </div>
                <Skeleton className="h-3 w-48" />
                <div className="flex items-center gap-2">
                  <Skeleton className="h-5 w-14 rounded-full" />
                  <Skeleton className="h-5 w-14 rounded-full" />
                </div>
              </Card>
            ))}
          </div>
        ) : (
          <div className="rounded-lg border border-border bg-card">
            {[1, 2, 3, 4].map((i) => (
              <div key={i} className="flex items-center gap-4 border-b border-border px-4 py-3 last:border-b-0">
                <Skeleton className="h-4 w-32" />
                <Skeleton className="h-4 w-40" />
                <Skeleton className="h-5 w-14 rounded-full" />
                <Skeleton className="h-5 w-14 rounded-full" />
                <Skeleton className="ml-auto h-7 w-20" />
              </div>
            ))}
          </div>
        )
      ) : viewMode === 'grid' ? (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {filtered.map((project) => {
            const toolMeta = toolsByName.get(project.name);

            return (
              <div key={project.name} className="space-y-2">
                <ProjectCard
                  project={project}
                  onActivate={activate}
                  onDeactivate={deactivate}
                  onRestart={restart}
                />
                {toolMeta && (
                  <div className="space-y-1 rounded-md border border-input bg-muted/40 px-2 py-1.5">
                    {toolMeta.description && (
                      <p className="line-clamp-2 text-xs text-muted-foreground">{toolMeta.description}</p>
                    )}
                    <div className="flex flex-wrap items-center gap-1 text-xs text-muted-foreground">
                      {toolMeta.risk ? (
                        <span className="rounded bg-muted px-1.5 py-0.5">risk: {toolMeta.risk}</span>
                      ) : null}
                      {toolMeta.triggers.length > 0 ? (
                        <span className="rounded bg-muted px-1.5 py-0.5">
                          triggers: {toolMeta.triggers.slice(0, 3).join(', ')}
                        </span>
                      ) : null}
                    </div>
                  </div>
                )}
                <div className="flex items-center gap-1">
                  <Select
                    value={project.kind}
                    onChange={(e) => handleKindChange(project, e.target.value as ProjectKind)}
                    className="h-8 flex-1 text-xs"
                  >
                    <option value="project">Project</option>
                    <option value="service">API / Service</option>
                    <option value="tool">Tool</option>
                    <option value="website">Site</option>
                    <option value="capability">Capability</option>
                  </Select>
                  <Button
                    variant="ghost"
                    size="icon"
                    onClick={() => handleToggleHidden(project)}
                    title={project.enabled === false ? 'Show project' : 'Hide project'}
                    aria-label={project.enabled === false ? 'Show project' : 'Hide project'}
                  >
                    {project.enabled === false ? (
                      <Eye className="h-3.5 w-3.5" />
                    ) : (
                      <EyeOff className="h-3.5 w-3.5" />
                    )}
                  </Button>
                  <Button
                    variant="ghost"
                    size="icon"
                    onClick={() => handleDelete(project)}
                    title="Remove project"
                    aria-label="Remove project"
                    className="hover:text-destructive"
                  >
                    <Trash2 className="h-3.5 w-3.5" />
                  </Button>
                </div>
              </div>
            );
          })}
        </div>
      ) : (
        <div className="rounded-lg border border-border bg-card">
          <table className="w-full">
            <thead>
              <tr className="border-b border-border text-left text-xs text-muted-foreground">
                <th className="px-4 py-3 font-medium">Name</th>
                <th className="px-4 py-3 font-medium">Domain</th>
                <th className="px-4 py-3 font-medium">Type</th>
                <th className="px-4 py-3 font-medium">Category</th>
                <th className="px-4 py-3 font-medium">Status</th>
                <th className="px-4 py-3 font-medium">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {filtered.map((project) => {
                const isRunning = project.status === 'running';
                const isBusy =
                  project.status === 'starting' || project.status === 'stopping';

                return (
                  <tr
                    key={project.name}
                    className={cn('hover:bg-accent/50', project.enabled === false && 'opacity-60')}
                  >
                    <td className="px-4 py-3">
                      <Link
                        to={`/projects/${encodeURIComponent(project.name)}`}
                        className="text-sm font-medium hover:text-primary"
                      >
                        {project.name}
                      </Link>
                      {toolsByName.get(project.name)?.description && (
                        <p className="mt-0.5 line-clamp-1 text-xs text-muted-foreground">
                          {toolsByName.get(project.name)?.description}
                        </p>
                      )}
                      {toolsByName.get(project.name)?.triggers.length ? (
                        <p className="mt-0.5 line-clamp-1 text-xs text-muted-foreground">
                          triggers: {toolsByName.get(project.name)?.triggers.slice(0, 3).join(', ')}
                        </p>
                      ) : null}
                    </td>
                    <td className="px-4 py-3 text-sm text-muted-foreground">
                      {project.domain}
                    </td>
                    <td className="px-4 py-3">
                      <TypeBadge type={project.type} />
                    </td>
                    <td className="px-4 py-3">
                      <Select
                        value={project.kind}
                        onChange={(e) => handleKindChange(project, e.target.value as ProjectKind)}
                        className="h-8 text-xs"
                      >
                        <option value="project">Project</option>
                        <option value="service">API / Service</option>
                        <option value="tool">Tool</option>
                        <option value="website">Site</option>
                        <option value="capability">Capability</option>
                      </Select>
                    </td>
                    <td className="px-4 py-3">
                      <StatusBadge status={project.status} />
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-1">
                        {isRunning ? (
                          <Button
                            variant="ghost"
                            size="icon"
                            onClick={() => deactivate(project.name)}
                            disabled={isBusy}
                            title="Stop"
                            aria-label="Stop"
                            className="h-7 w-7"
                          >
                            <Square className="h-3.5 w-3.5" />
                          </Button>
                        ) : (
                          <Button
                            variant="ghost"
                            size="icon"
                            onClick={() => activate(project.name)}
                            disabled={isBusy || project.enabled === false}
                            title="Start"
                            aria-label="Start"
                            className="h-7 w-7"
                          >
                            <Play className="h-3.5 w-3.5" />
                          </Button>
                        )}

                        <Button
                          variant="ghost"
                          size="icon"
                          onClick={() => handleToggleHidden(project)}
                          title={project.enabled === false ? 'Show project' : 'Hide project'}
                          aria-label={project.enabled === false ? 'Show project' : 'Hide project'}
                          className="h-7 w-7"
                        >
                          {project.enabled === false ? (
                            <Eye className="h-3.5 w-3.5" />
                          ) : (
                            <EyeOff className="h-3.5 w-3.5" />
                          )}
                        </Button>

                        <Button
                          variant="ghost"
                          size="icon"
                          onClick={() => handleDelete(project)}
                          title="Remove project"
                          aria-label="Remove project"
                          className="h-7 w-7 hover:text-destructive"
                        >
                          <Trash2 className="h-3.5 w-3.5" />
                        </Button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
          {filtered.length === 0 && (
            <p className="p-6 text-center text-sm text-muted-foreground">
              No projects match your filters.
            </p>
          )}
        </div>
      )}

      <Modal
        open={showCreate}
        onClose={() => setShowCreate(false)}
        title="Add Tool / Site / API"
        className="max-w-2xl"
      >
        <EntryForm
          mode="create"
          onSubmit={handleCreate}
          onCancel={() => setShowCreate(false)}
          submitLabel="Add Entry"
        />
      </Modal>

      <ConfirmDialog
        open={confirmDelete !== null}
        onConfirm={handleConfirmDelete}
        onCancel={() => setConfirmDelete(null)}
        title="Remove project"
        message={`Remove project "${confirmDelete?.name}"? This action cannot be undone.`}
        confirmLabel="Remove"
      />
    </div>
  );
}
