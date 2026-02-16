import { useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom';
import {
  ExternalLink,
  Copy,
  AlertCircle,
  FolderKanban,
  Activity,
  Heart,
  RefreshCw,
} from 'lucide-react';
import { useProjects } from '../hooks/useProjects';
import { useHealth } from '../hooks/useHealth';
import { useAppStore } from '../stores/appStore';
import { api } from '../api/client';
import { HealthStrip } from '../components/common/HealthStrip';
import { StatusBadge } from '../components/common/StatusBadge';
import { Button } from '../components/ui/Button';
import { Card, CardHeader, CardTitle, CardContent } from '../components/ui/Card';
import { Skeleton } from '../components/ui/Skeleton';

export function Dashboard() {
  const { projects, allProjects } = useProjects();
  const { health, daemonConnected } = useHealth();
  const projectHealth = useAppStore((s) => s.projectHealth);
  const setProjectHealth = useAppStore((s) => s.setProjectHealth);
  const projectsLoaded = useAppStore((s) => s.projectsLoaded);

  const fetchProjectHealth = useCallback(async () => {
    try {
      const res = await api.getProjectHealthAll();
      setProjectHealth(res.data);
    } catch (err) {
      console.warn('Failed to fetch project health:', err);
    }
  }, [setProjectHealth]);

  useEffect(() => {
    fetchProjectHealth();
    const interval = setInterval(fetchProjectHealth, 30_000);
    return () => clearInterval(interval);
  }, [fetchProjectHealth]);

  const running = projects.filter((p) => p.status === 'running');
  const errors = projects.filter((p) => p.status === 'error');
  const needsConfig = projects.filter((p) => p.status === 'needs_config');

  // Filter projectHealth entries to only show projects matching the search
  const filteredProjectNames = new Set(projects.map((p) => p.name));
  const filteredProjectHealth = Object.entries(projectHealth).filter(
    ([name]) => filteredProjectNames.has(name)
  );

  const copyUrl = (domain: string) => {
    navigator.clipboard.writeText(`https://${domain}`);
  };

  return (
    <div className="space-y-6">
      {/* Health strip */}
      <HealthStrip health={health} daemonConnected={daemonConnected} />

      {/* Stats row */}
      {!projectsLoaded ? (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {[1, 2, 3].map((i) => (
            <Card key={i} className="p-4">
              <div className="flex items-center gap-3">
                <Skeleton className="h-10 w-10 rounded-lg" />
                <div>
                  <Skeleton className="h-7 w-16" />
                  <Skeleton className="mt-1 h-3 w-20" />
                </div>
              </div>
            </Card>
          ))}
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <Card className="p-4">
            <div className="flex items-center gap-3">
              <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-primary/10">
                <FolderKanban className="h-5 w-5 text-primary" />
              </div>
              <div>
                <p className="text-2xl font-bold">{allProjects.length}</p>
                <p className="text-xs text-muted-foreground">Total projects</p>
              </div>
            </div>
          </Card>
          <Card className="p-4">
            <div className="flex items-center gap-3">
              <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-green-500/10">
                <Activity className="h-5 w-5 text-green-500" />
              </div>
              <div>
                <p className="text-2xl font-bold">{running.length}</p>
                <p className="text-xs text-muted-foreground">Running</p>
              </div>
            </div>
          </Card>
          <Card className="p-4">
            <div className="flex items-center gap-3">
              <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-red-500/10">
                <AlertCircle className="h-5 w-5 text-red-500" />
              </div>
              <div>
                <p className="text-2xl font-bold">{errors.length}</p>
                <p className="text-xs text-muted-foreground">Errors</p>
              </div>
            </div>
          </Card>
        </div>
      )}

      {/* Project Health Overview */}
      {filteredProjectHealth.length > 0 && (
        <Card>
          <CardHeader className="flex flex-row items-center justify-between">
            <div className="flex items-center gap-2">
              <Heart className="h-4 w-4 text-muted-foreground" />
              <CardTitle>Project Health</CardTitle>
            </div>
            <Button
              variant="ghost"
              size="icon"
              onClick={fetchProjectHealth}
              title="Refresh health"
              aria-label="Refresh health"
              className="h-7 w-7"
            >
              <RefreshCw className="h-3.5 w-3.5" />
            </Button>
          </CardHeader>
          <div className="grid grid-cols-2 gap-px bg-border sm:grid-cols-3 lg:grid-cols-4">
            {filteredProjectHealth.map(([name, status]) => (
              <Link
                key={name}
                to={`/projects/${encodeURIComponent(name)}`}
                className="flex items-center gap-2 bg-card px-3 py-2.5 hover:bg-accent/50"
              >
                <span
                  className={`h-2 w-2 shrink-0 rounded-full ${
                    status.status === 'healthy'
                      ? 'bg-green-500'
                      : status.status === 'unhealthy'
                        ? 'bg-red-500'
                        : status.status === 'unreachable'
                          ? 'bg-yellow-500'
                          : 'bg-gray-500'
                  }`}
                />
                <span className="truncate text-xs font-medium">{name}</span>
                {status.latency_ms != null && (
                  <span className="ml-auto shrink-0 text-xs text-muted-foreground">
                    {status.latency_ms}ms
                  </span>
                )}
              </Link>
            ))}
          </div>
        </Card>
      )}

      {/* Active routes */}
      <Card>
        <CardHeader>
          <CardTitle>Active Routes</CardTitle>
        </CardHeader>
        {running.length === 0 ? (
          <CardContent>
            <p className="text-center text-sm text-muted-foreground">
              No active routes.{' '}
              <Link
                to="/projects"
                className="text-primary hover:underline"
              >
                Activate a project
              </Link>
            </p>
          </CardContent>
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
                  <Button
                    variant="ghost"
                    size="icon"
                    onClick={() => copyUrl(project.domain)}
                    title="Copy URL"
                    aria-label="Copy URL"
                    className="h-7 w-7"
                  >
                    <Copy className="h-3.5 w-3.5" />
                  </Button>
                  <a
                    href={`https://${project.domain}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex h-7 w-7 items-center justify-center rounded-md text-muted-foreground hover:bg-accent hover:text-foreground"
                    title="Open in browser"
                    aria-label="Open in browser"
                  >
                    <ExternalLink className="h-3.5 w-3.5" />
                  </a>
                </div>
              </div>
            ))}
          </div>
        )}
      </Card>

      {/* Errors & warnings — custom border colors, skip Card primitive */}
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
