import { useEffect, useState, useCallback } from 'react';
import { useParams, Link } from 'react-router-dom';
import {
  ArrowLeft,
  Play,
  Square,
  RotateCw,
  ExternalLink,
  Copy,
} from 'lucide-react';
import { cn } from '../lib/utils';
import { api } from '../api/client';
import { useAppStore } from '../stores/appStore';
import { useLogs } from '../hooks/useLogs';
import { StatusBadge } from '../components/common/StatusBadge';
import { TypeBadge } from '../components/common/TypeBadge';
import { LogViewer } from '../components/common/LogViewer';
import type { Project } from '../types';

type Tab = 'overview' | 'run' | 'routing' | 'mail' | 'logs';

export function ProjectDetail() {
  const { name } = useParams<{ name: string }>();
  const [activeTab, setActiveTab] = useState<Tab>('overview');
  const updateProject = useAppStore((s) => s.updateProject);
  const project = useAppStore((s) =>
    s.projects.find((p) => p.name === name)
  );
  const { logs, clear: clearLogs } = useLogs(name || '');

  const fetchProject = useCallback(async () => {
    if (!name) return;
    try {
      const res = await api.getProject(name);
      updateProject(name, res.data);
    } catch (err) {
      console.error('Failed to fetch project:', err);
    }
  }, [name, updateProject]);

  useEffect(() => {
    fetchProject();
  }, [fetchProject]);

  if (!project) {
    return (
      <div className="flex items-center justify-center h-64">
        <p className="text-muted-foreground">Loading project...</p>
      </div>
    );
  }

  const isRunning = project.status === 'running';
  const isBusy =
    project.status === 'starting' || project.status === 'stopping';
  const url = `https://${project.domain}`;

  const handleActivate = async () => {
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

  const tabs: { id: Tab; label: string }[] = [
    { id: 'overview', label: 'Overview' },
    { id: 'run', label: 'Run' },
    { id: 'routing', label: 'Routing' },
    { id: 'mail', label: 'Mail' },
    { id: 'logs', label: 'Logs' },
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center gap-4">
        <Link
          to="/projects"
          className="inline-flex h-8 w-8 items-center justify-center rounded-md text-muted-foreground hover:bg-accent hover:text-foreground"
        >
          <ArrowLeft className="h-4 w-4" />
        </Link>
        <div className="flex-1">
          <div className="flex items-center gap-3">
            <h1 className="text-xl font-bold">{project.name}</h1>
            <TypeBadge type={project.type} />
            <StatusBadge status={project.status} />
          </div>
          <p className="mt-1 text-sm text-muted-foreground">{project.path}</p>
        </div>
        <div className="flex items-center gap-2">
          {isRunning ? (
            <>
              <button
                onClick={handleDeactivate}
                disabled={isBusy}
                className="inline-flex items-center gap-2 rounded-md bg-destructive/10 px-3 py-2 text-sm font-medium text-destructive hover:bg-destructive/20 disabled:opacity-50"
              >
                <Square className="h-4 w-4" />
                Stop
              </button>
              <button
                onClick={handleRestart}
                disabled={isBusy}
                className="inline-flex items-center gap-2 rounded-md bg-accent px-3 py-2 text-sm font-medium hover:bg-accent/80 disabled:opacity-50"
              >
                <RotateCw className="h-4 w-4" />
                Restart
              </button>
            </>
          ) : (
            <button
              onClick={handleActivate}
              disabled={isBusy}
              className="inline-flex items-center gap-2 rounded-md bg-primary px-3 py-2 text-sm font-medium text-primary-foreground hover:bg-primary/90 disabled:opacity-50"
            >
              <Play className="h-4 w-4" />
              Start
            </button>
          )}
          {isRunning && (
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
      <div className="flex border-b border-border">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={cn(
              'px-4 py-2 text-sm font-medium transition-colors border-b-2 -mb-px',
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
      {activeTab === 'overview' && (
        <OverviewTab project={project} />
      )}
      {activeTab === 'run' && <RunTab project={project} />}
      {activeTab === 'routing' && <RoutingTab project={project} />}
      {activeTab === 'mail' && <MailTab project={project} />}
      {activeTab === 'logs' && (
        <LogViewer logs={logs} onClear={clearLogs} className="h-[500px]" />
      )}
    </div>
  );
}

function OverviewTab({ project }: { project: Project }) {
  const url = `https://${project.domain}`;

  return (
    <div className="grid grid-cols-2 gap-6">
      <div className="space-y-4">
        <div className="rounded-lg border border-border bg-card p-4">
          <h3 className="text-sm font-semibold mb-3">Details</h3>
          <dl className="space-y-2 text-sm">
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Domain</dt>
              <dd className="flex items-center gap-1">
                {project.domain}
                <button
                  onClick={() => navigator.clipboard.writeText(url)}
                  className="text-muted-foreground hover:text-foreground"
                >
                  <Copy className="h-3 w-3" />
                </button>
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Port</dt>
              <dd>{project.port || 'N/A'}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Type</dt>
              <dd><TypeBadge type={project.type} /></dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Detection</dt>
              <dd className="capitalize">
                {project.detection.confidence} ({project.detection.source})
              </dd>
            </div>
            {project.template && (
              <div className="flex justify-between">
                <dt className="text-muted-foreground">Template</dt>
                <dd>{project.template}</dd>
              </div>
            )}
            {project.pid && (
              <div className="flex justify-between">
                <dt className="text-muted-foreground">PID</dt>
                <dd className="font-mono">{project.pid}</dd>
              </div>
            )}
          </dl>
        </div>
      </div>

      <div className="space-y-4">
        <div className="rounded-lg border border-border bg-card p-4">
          <h3 className="text-sm font-semibold mb-3">Features</h3>
          <div className="space-y-2">
            {Object.entries(project.features).map(([key, value]) => (
              <div key={key} className="flex items-center justify-between text-sm">
                <span className="text-muted-foreground capitalize">
                  {key.replace(/_/g, ' ')}
                </span>
                <span
                  className={cn(
                    'text-xs font-medium',
                    value ? 'text-green-500' : 'text-muted-foreground'
                  )}
                >
                  {value ? 'Enabled' : 'Disabled'}
                </span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function RunTab({ project }: { project: Project }) {
  return (
    <div className="space-y-4">
      <div className="rounded-lg border border-border bg-card p-4">
        <h3 className="text-sm font-semibold mb-3">Run Configuration</h3>
        <dl className="space-y-3 text-sm">
          <div>
            <dt className="text-muted-foreground mb-1">Command</dt>
            <dd className="rounded-md bg-muted px-3 py-2 font-mono text-xs">
              {project.run_cmd || 'Not configured'}
            </dd>
          </div>
          <div>
            <dt className="text-muted-foreground mb-1">Working Directory</dt>
            <dd className="rounded-md bg-muted px-3 py-2 font-mono text-xs">
              {project.run_cwd || '.'}
            </dd>
          </div>
          {project.run_env && Object.keys(project.run_env).length > 0 && (
            <div>
              <dt className="text-muted-foreground mb-1">
                Environment Variables
              </dt>
              <dd className="space-y-1">
                {Object.entries(project.run_env).map(([key, value]) => (
                  <div
                    key={key}
                    className="rounded-md bg-muted px-3 py-1.5 font-mono text-xs"
                  >
                    <span className="text-primary">{key}</span>=
                    <span>{value}</span>
                  </div>
                ))}
              </dd>
            </div>
          )}
        </dl>
      </div>
    </div>
  );
}

function RoutingTab({ project }: { project: Project }) {
  return (
    <div className="space-y-4">
      <div className="rounded-lg border border-border bg-card p-4">
        <h3 className="text-sm font-semibold mb-3">Routing</h3>
        <dl className="space-y-3 text-sm">
          <div className="flex justify-between">
            <dt className="text-muted-foreground">Primary Domain</dt>
            <dd>{project.domain}</dd>
          </div>
          {project.root && (
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Document Root</dt>
              <dd className="font-mono text-xs">{project.root}</dd>
            </div>
          )}
          {project.port && (
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Upstream Port</dt>
              <dd className="font-mono text-xs">{project.port}</dd>
            </div>
          )}
        </dl>
      </div>
    </div>
  );
}

function MailTab({ project }: { project: Project }) {
  const mailEnabled = project.features.mailpit;

  return (
    <div className="space-y-4">
      <div className="rounded-lg border border-border bg-card p-4">
        <h3 className="text-sm font-semibold mb-3">Mail Configuration</h3>
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm">Mailpit Integration</p>
            <p className="text-xs text-muted-foreground">
              Capture outgoing mail via SMTP on localhost:1025
            </p>
          </div>
          <span
            className={cn(
              'text-sm font-medium',
              mailEnabled ? 'text-green-500' : 'text-muted-foreground'
            )}
          >
            {mailEnabled ? 'Enabled' : 'Disabled'}
          </span>
        </div>
        {mailEnabled && (
          <div className="mt-4 space-y-2 text-sm">
            <div className="flex justify-between">
              <span className="text-muted-foreground">SMTP</span>
              <span className="font-mono text-xs">127.0.0.1:1025</span>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">Inbox</span>
              <a
                href="http://127.0.0.1:8025"
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center gap-1 text-primary hover:underline"
              >
                Open Mailpit
                <ExternalLink className="h-3 w-3" />
              </a>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
