import { Link } from 'react-router-dom';
import {
  ExternalLink,
  Copy,
  AlertCircle,
  FolderKanban,
  Activity,
} from 'lucide-react';
import { useProjects } from '../hooks/useProjects';
import { useHealth } from '../hooks/useHealth';
import { HealthStrip } from '../components/common/HealthStrip';
import { StatusBadge } from '../components/common/StatusBadge';

export function Dashboard() {
  const { allProjects } = useProjects();
  const { health, daemonConnected } = useHealth();

  const running = allProjects.filter((p) => p.status === 'running');
  const errors = allProjects.filter((p) => p.status === 'error');
  const needsConfig = allProjects.filter((p) => p.status === 'needs_config');

  const copyUrl = (domain: string) => {
    navigator.clipboard.writeText(`https://${domain}`);
  };

  return (
    <div className="space-y-6">
      {/* Health strip */}
      <HealthStrip health={health} daemonConnected={daemonConnected} />

      {/* Stats row */}
      <div className="grid grid-cols-3 gap-4">
        <div className="rounded-lg border border-border bg-card p-4">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-primary/10">
              <FolderKanban className="h-5 w-5 text-primary" />
            </div>
            <div>
              <p className="text-2xl font-bold">{allProjects.length}</p>
              <p className="text-xs text-muted-foreground">Total projects</p>
            </div>
          </div>
        </div>
        <div className="rounded-lg border border-border bg-card p-4">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-green-500/10">
              <Activity className="h-5 w-5 text-green-500" />
            </div>
            <div>
              <p className="text-2xl font-bold">{running.length}</p>
              <p className="text-xs text-muted-foreground">Running</p>
            </div>
          </div>
        </div>
        <div className="rounded-lg border border-border bg-card p-4">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-red-500/10">
              <AlertCircle className="h-5 w-5 text-red-500" />
            </div>
            <div>
              <p className="text-2xl font-bold">{errors.length}</p>
              <p className="text-xs text-muted-foreground">Errors</p>
            </div>
          </div>
        </div>
      </div>

      {/* Active routes */}
      <div className="rounded-lg border border-border bg-card">
        <div className="border-b border-border px-4 py-3">
          <h2 className="text-sm font-semibold">Active Routes</h2>
        </div>
        {running.length === 0 ? (
          <div className="p-6 text-center text-sm text-muted-foreground">
            No active routes.{' '}
            <Link
              to="/projects"
              className="text-primary hover:underline"
            >
              Activate a project
            </Link>
          </div>
        ) : (
          <div className="divide-y divide-border">
            {running.map((project) => (
              <div
                key={project.name}
                className="flex items-center justify-between px-4 py-3"
              >
                <div className="flex items-center gap-3">
                  <StatusBadge status={project.status} />
                  <Link
                    to={`/projects/${encodeURIComponent(project.name)}`}
                    className="text-sm font-medium hover:text-primary"
                  >
                    {project.name}
                  </Link>
                  <span className="text-xs text-muted-foreground">
                    {project.domain}
                  </span>
                </div>
                <div className="flex items-center gap-1">
                  <button
                    onClick={() => copyUrl(project.domain)}
                    className="inline-flex h-7 w-7 items-center justify-center rounded-md text-muted-foreground hover:bg-accent hover:text-foreground"
                    title="Copy URL"
                  >
                    <Copy className="h-3.5 w-3.5" />
                  </button>
                  <a
                    href={`https://${project.domain}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex h-7 w-7 items-center justify-center rounded-md text-muted-foreground hover:bg-accent hover:text-foreground"
                    title="Open in browser"
                  >
                    <ExternalLink className="h-3.5 w-3.5" />
                  </a>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Errors & warnings */}
      {(errors.length > 0 || needsConfig.length > 0) && (
        <div className="rounded-lg border border-red-500/20 bg-red-500/5">
          <div className="border-b border-red-500/20 px-4 py-3">
            <h2 className="text-sm font-semibold text-red-400">
              Issues ({errors.length + needsConfig.length})
            </h2>
          </div>
          <div className="divide-y divide-red-500/10">
            {[...errors, ...needsConfig].map((project) => (
              <Link
                key={project.name}
                to={`/projects/${encodeURIComponent(project.name)}`}
                className="flex items-center gap-3 px-4 py-3 hover:bg-red-500/5"
              >
                <StatusBadge status={project.status} />
                <span className="text-sm">{project.name}</span>
              </Link>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
