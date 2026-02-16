import { useEffect, useState } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import {
  ArrowLeft,
  Play,
  Square,
  RotateCw,
  ExternalLink,
} from 'lucide-react';
import { cn } from '../lib/utils';
import { api } from '../api/client';
import { useAppStore } from '../stores/appStore';
import { useLogs } from '../hooks/useLogs';
import { StatusBadge } from '../components/common/StatusBadge';
import { TypeBadge } from '../components/common/TypeBadge';
import { LogViewer } from '../components/common/LogViewer';
import { Button } from '../components/ui/Button';
import { Skeleton } from '../components/ui/Skeleton';
import { OverviewTab } from '../components/project-detail/OverviewTab';
import { EntryTab } from '../components/project-detail/EntryTab';
import { RunTab } from '../components/project-detail/RunTab';
import { RoutingTab } from '../components/project-detail/RoutingTab';
import { DocsTab } from '../components/project-detail/DocsTab';
import { EndpointsTab } from '../components/project-detail/EndpointsTab';
import { HealthTab } from '../components/project-detail/HealthTab';
import { DependenciesTab } from '../components/project-detail/DependenciesTab';
import { DeployTab } from '../components/project-detail/DeployTab';
import { MailTab } from '../components/project-detail/MailTab';
import type { Project } from '../types';

type Tab =
  | 'overview'
  | 'entry'
  | 'run'
  | 'routing'
  | 'mail'
  | 'logs'
  | 'docs'
  | 'endpoints'
  | 'health'
  | 'dependencies'
  | 'deploy';

export function ProjectDetail() {
  const navigate = useNavigate();
  const { name: routeName } = useParams<{ name: string }>();
  const projectName = routeName
    ? (() => {
        try {
          return decodeURIComponent(routeName);
        } catch {
          return routeName;
        }
      })()
    : null;
  const [activeTab, setActiveTab] = useState<Tab>('overview');
  const [loadError, setLoadError] = useState<string | null>(null);
  const updateProject = useAppStore((s) => s.updateProject);
  const addToast = useAppStore((s) => s.addToast);
  const setProjects = useAppStore((s) => s.setProjects);
  const upsertProject = useAppStore((s) => s.upsertProject);
  const project = useAppStore((s) =>
    s.projects.find((p) => p.name === projectName)
  );
  const logsTabActive = activeTab === 'logs';
  const { logs, clear: clearLogs } = useLogs(projectName || '', logsTabActive);

  useEffect(() => {
    let cancelled = false;

    if (!projectName) {
      setLoadError('Invalid project URL');
      return () => {
        cancelled = true;
      };
    }

    setLoadError(null);

    api
      .getProject(projectName)
      .then((res) => {
        if (cancelled) return;
        upsertProject(res.data);
      })
      .catch((err) => {
        if (cancelled) return;
        const message =
          err instanceof Error ? err.message : 'Failed to load project';
        setLoadError(message);
        console.error('Failed to fetch project:', err);
      });

    return () => {
      cancelled = true;
    };
  }, [projectName, upsertProject]);

  if (!project) {
    if (loadError) {
      return (
        <div className="space-y-3">
          <Link
            to="/projects"
            className="inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground"
          >
            <ArrowLeft className="h-4 w-4" />
            Back to Projects
          </Link>
          <div className="flex items-center justify-center h-64 rounded-lg border border-border bg-card">
            <p className="text-muted-foreground">
              Project could not be loaded: {loadError}
            </p>
          </div>
        </div>
      );
    }

    return (
      <div className="space-y-6">
        {/* Skeleton header */}
        <div className="flex items-center gap-4">
          <Skeleton className="h-8 w-8 rounded-md" />
          <div className="flex-1 space-y-2">
            <div className="flex items-center gap-3">
              <Skeleton className="h-6 w-48" />
              <Skeleton className="h-5 w-14 rounded-full" />
              <Skeleton className="h-5 w-16 rounded-full" />
            </div>
            <Skeleton className="h-4 w-64" />
          </div>
          <Skeleton className="h-9 w-20 rounded-md" />
        </div>

        {/* Skeleton tab bar */}
        <div className="flex gap-4 border-b border-border pb-px">
          {[1, 2, 3, 4, 5].map((i) => (
            <Skeleton key={i} className="h-4 w-16 mb-2" />
          ))}
        </div>

        {/* Skeleton content */}
        <div className="space-y-4">
          <Skeleton className="h-32 w-full rounded-lg" />
          <Skeleton className="h-24 w-full rounded-lg" />
        </div>
      </div>
    );
  }

  const isRunning = project.status === 'running';
  const isBusy =
    project.status === 'starting' || project.status === 'stopping';
  const url = project.domain ? `https://${project.domain}` : '';

  const handleActivate = async () => {
    if (project.enabled === false) {
      addToast({
        type: 'warning',
        message: 'This project is hidden. Unhide it before starting.',
      });
      return;
    }

    updateProject(project.name, { status: 'starting' });
    try {
      const res = await api.activateProject(project.name);
      updateProject(project.name, res.data);
    } catch {
      updateProject(project.name, { status: 'error' });
    }
  };

  const handleDeactivate = async () => {
    updateProject(project.name, { status: 'stopping' });
    try {
      const res = await api.deactivateProject(project.name);
      updateProject(project.name, res.data);
    } catch {
      updateProject(project.name, { status: 'error' });
    }
  };

  const handleRestart = async () => {
    updateProject(project.name, { status: 'starting' });
    try {
      const res = await api.restartProject(project.name);
      updateProject(project.name, res.data);
    } catch {
      updateProject(project.name, { status: 'error' });
    }
  };

  const handleProjectUpdated = (updated: Project) => {
    if (projectName && updated.name !== projectName) {
      const current = useAppStore.getState().projects;
      const next = current.filter(
        (p) => p.name !== projectName && p.name !== updated.name
      );
      setProjects([...next, updated]);
      navigate(`/projects/${encodeURIComponent(updated.name)}`, {
        replace: true,
      });
      return;
    }

    upsertProject(updated);
  };

  const tabs: { id: Tab; label: string }[] = [
    { id: 'overview', label: 'Overview' },
    { id: 'entry', label: 'Entry' },
    { id: 'run', label: 'Run' },
    { id: 'routing', label: 'Routing' },
    ...(project.docs?.length ? [{ id: 'docs' as Tab, label: 'Docs' }] : []),
    ...(project.endpoints?.length ? [{ id: 'endpoints' as Tab, label: 'Endpoints' }] : []),
    ...(project.health_endpoint ? [{ id: 'health' as Tab, label: 'Health' }] : []),
    ...(project.depends_on?.length || project.kind === 'service' ? [{ id: 'dependencies' as Tab, label: 'Dependencies' }] : []),
    ...(project.deploy && Object.keys(project.deploy).length ? [{ id: 'deploy' as Tab, label: 'Deploy' }] : []),
    { id: 'mail', label: 'Mail' },
    { id: 'logs', label: 'Logs' },
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center gap-4">
        <Link
          to="/projects"
          aria-label="Back to projects"
          className="inline-flex h-8 w-8 items-center justify-center rounded-md text-muted-foreground hover:bg-accent hover:text-foreground"
        >
          <ArrowLeft className="h-4 w-4" />
        </Link>
        <div className="flex-1">
          <div className="flex items-center gap-3">
            <h1 className="text-xl font-bold">{project.name}</h1>
            <TypeBadge type={project.type} />
            <StatusBadge status={project.status} />
            {project.kind !== 'project' && (
              <span className="rounded-full bg-blue-500/10 px-2 py-0.5 text-xs font-medium text-blue-400">
                {project.kind}
              </span>
            )}
          </div>
          <p className="mt-1 text-sm text-muted-foreground">
            {project.description || project.path}
          </p>
          {project.tags?.length > 0 && (
            <div className="mt-1 flex gap-1">
              {project.tags.map((tag) => (
                <span key={tag} className="rounded bg-muted px-1.5 py-0.5 text-xs text-muted-foreground">
                  {tag}
                </span>
              ))}
            </div>
          )}
        </div>
        <div className="flex items-center gap-2">
          {isRunning ? (
            <>
              <Button
                variant="destructive"
                onClick={handleDeactivate}
                disabled={isBusy}
              >
                <Square className="h-4 w-4" />
                Stop
              </Button>
              <Button
                variant="secondary"
                onClick={handleRestart}
                disabled={isBusy}
              >
                <RotateCw className="h-4 w-4" />
                Restart
              </Button>
            </>
          ) : (
            <Button
              onClick={handleActivate}
              disabled={isBusy || project.enabled === false}
            >
              <Play className="h-4 w-4" />
              Start
            </Button>
          )}
          {isRunning && project.domain && (
            <a
              href={url}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 rounded-md border border-input px-3 py-2 text-sm hover:bg-accent"
            >
              <ExternalLink className="h-4 w-4" />
              Open
            </a>
          )}
        </div>
      </div>

      {/* Tabs */}
      <div
        role="tablist"
        aria-label="Project sections"
        className="flex border-b border-border overflow-x-auto"
        onKeyDown={(e) => {
          if (e.key === 'ArrowRight' || e.key === 'ArrowLeft') {
            e.preventDefault();
            const currentIndex = tabs.findIndex((t) => t.id === activeTab);
            const nextIndex =
              e.key === 'ArrowRight'
                ? (currentIndex + 1) % tabs.length
                : (currentIndex - 1 + tabs.length) % tabs.length;
            setActiveTab(tabs[nextIndex].id);
            const nextButton = document.getElementById(`tab-${tabs[nextIndex].id}`);
            nextButton?.focus();
          }
        }}
      >
        {tabs.map((tab) => (
          <button
            key={tab.id}
            id={`tab-${tab.id}`}
            role="tab"
            aria-selected={activeTab === tab.id}
            aria-controls={`tabpanel-${tab.id}`}
            tabIndex={activeTab === tab.id ? 0 : -1}
            onClick={() => setActiveTab(tab.id)}
            className={cn(
              'px-4 py-2 text-sm font-medium transition-colors border-b-2 -mb-px whitespace-nowrap',
              activeTab === tab.id
                ? 'border-primary text-foreground'
                : 'border-transparent text-muted-foreground hover:text-foreground'
            )}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Tab content */}
      <div
        role="tabpanel"
        id={`tabpanel-${activeTab}`}
        aria-labelledby={`tab-${activeTab}`}
      >
        {activeTab === 'overview' && <OverviewTab project={project} />}
        {activeTab === 'entry' && <EntryTab project={project} onProjectUpdated={handleProjectUpdated} />}
        {activeTab === 'run' && <RunTab project={project} onProjectUpdated={handleProjectUpdated} />}
        {activeTab === 'routing' && <RoutingTab project={project} onProjectUpdated={handleProjectUpdated} />}
        {activeTab === 'docs' && <DocsTab project={project} onProjectUpdated={handleProjectUpdated} />}
        {activeTab === 'endpoints' && <EndpointsTab project={project} />}
        {activeTab === 'health' && <HealthTab project={project} />}
        {activeTab === 'dependencies' && <DependenciesTab project={project} />}
        {activeTab === 'deploy' && <DeployTab project={project} />}
        {activeTab === 'mail' && <MailTab project={project} />}
        {activeTab === 'logs' && (
          <LogViewer logs={logs} onClear={clearLogs} className="h-[500px]" />
        )}
      </div>
    </div>
  );
}
