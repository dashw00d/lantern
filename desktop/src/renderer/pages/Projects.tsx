import { useState } from 'react';
import {
  LayoutGrid,
  List,
  RefreshCw,
  Play,
  Square,
} from 'lucide-react';
import { cn } from '../lib/utils';
import { useProjects } from '../hooks/useProjects';
import { useAppStore } from '../stores/appStore';
import { ProjectCard } from '../components/projects/ProjectCard';
import { StatusBadge } from '../components/common/StatusBadge';
import { TypeBadge } from '../components/common/TypeBadge';
import { Link } from 'react-router-dom';
import type { ProjectStatus, ProjectType } from '../types';

type FilterStatus = 'all' | ProjectStatus;
type FilterType = 'all' | ProjectType;

export function Projects() {
  const { projects, activate, deactivate, restart, scan } = useProjects();
  const viewMode = useAppStore((s) => s.projectViewMode);
  const setViewMode = useAppStore((s) => s.setProjectViewMode);
  const [statusFilter, setStatusFilter] = useState<FilterStatus>('all');
  const [typeFilter, setTypeFilter] = useState<FilterType>('all');
  const [scanning, setScanning] = useState(false);

  const filtered = projects.filter((p) => {
    if (statusFilter !== 'all' && p.status !== statusFilter) return false;
    if (typeFilter !== 'all' && p.type !== typeFilter) return false;
    return true;
  });

  const handleScan = async () => {
    setScanning(true);
    try {
      await scan();
    } finally {
      setScanning(false);
    }
  };

  return (
    <div className="space-y-4">
      {/* Toolbar */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          {/* Status filter */}
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value as FilterStatus)}
            className="h-9 rounded-md border border-input bg-background px-3 text-sm"
          >
            <option value="all">All Status</option>
            <option value="running">Running</option>
            <option value="stopped">Stopped</option>
            <option value="error">Error</option>
            <option value="needs_config">Needs Config</option>
          </select>

          {/* Type filter */}
          <select
            value={typeFilter}
            onChange={(e) => setTypeFilter(e.target.value as FilterType)}
            className="h-9 rounded-md border border-input bg-background px-3 text-sm"
          >
            <option value="all">All Types</option>
            <option value="php">PHP</option>
            <option value="proxy">Proxy</option>
            <option value="static">Static</option>
          </select>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={handleScan}
            disabled={scanning}
            className="inline-flex h-9 items-center gap-2 rounded-md border border-input bg-background px-3 text-sm hover:bg-accent disabled:opacity-50"
          >
            <RefreshCw
              className={cn('h-4 w-4', scanning && 'animate-spin')}
            />
            Scan
          </button>

          <div className="flex rounded-md border border-input">
            <button
              onClick={() => setViewMode('grid')}
              className={cn(
                'inline-flex h-9 w-9 items-center justify-center text-sm',
                viewMode === 'grid'
                  ? 'bg-accent text-foreground'
                  : 'text-muted-foreground hover:text-foreground'
              )}
            >
              <LayoutGrid className="h-4 w-4" />
            </button>
            <button
              onClick={() => setViewMode('list')}
              className={cn(
                'inline-flex h-9 w-9 items-center justify-center border-l border-input text-sm',
                viewMode === 'list'
                  ? 'bg-accent text-foreground'
                  : 'text-muted-foreground hover:text-foreground'
              )}
            >
              <List className="h-4 w-4" />
            </button>
          </div>
        </div>
      </div>

      {/* Project count */}
      <p className="text-sm text-muted-foreground">
        {filtered.length} project{filtered.length !== 1 ? 's' : ''}
      </p>

      {/* Grid view */}
      {viewMode === 'grid' ? (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {filtered.map((project) => (
            <ProjectCard
              key={project.name}
              project={project}
              onActivate={activate}
              onDeactivate={deactivate}
              onRestart={restart}
            />
          ))}
        </div>
      ) : (
        /* List view */
        <div className="rounded-lg border border-border bg-card">
          <table className="w-full">
            <thead>
              <tr className="border-b border-border text-left text-xs text-muted-foreground">
                <th className="px-4 py-3 font-medium">Name</th>
                <th className="px-4 py-3 font-medium">Domain</th>
                <th className="px-4 py-3 font-medium">Type</th>
                <th className="px-4 py-3 font-medium">Status</th>
                <th className="px-4 py-3 font-medium">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {filtered.map((project) => {
                const isRunning = project.status === 'running';
                const isBusy =
                  project.status === 'starting' ||
                  project.status === 'stopping';
                return (
                  <tr key={project.name} className="hover:bg-accent/50">
                    <td className="px-4 py-3">
                      <Link
                        to={`/projects/${project.name}`}
                        className="text-sm font-medium hover:text-primary"
                      >
                        {project.name}
                      </Link>
                    </td>
                    <td className="px-4 py-3 text-sm text-muted-foreground">
                      {project.domain}
                    </td>
                    <td className="px-4 py-3">
                      <TypeBadge type={project.type} />
                    </td>
                    <td className="px-4 py-3">
                      <StatusBadge status={project.status} />
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-1">
                        {isRunning ? (
                          <button
                            onClick={() => deactivate(project.name)}
                            disabled={isBusy}
                            className="inline-flex h-7 w-7 items-center justify-center rounded-md text-muted-foreground hover:bg-accent hover:text-foreground disabled:opacity-50"
                          >
                            <Square className="h-3.5 w-3.5" />
                          </button>
                        ) : (
                          <button
                            onClick={() => activate(project.name)}
                            disabled={isBusy}
                            className="inline-flex h-7 w-7 items-center justify-center rounded-md text-muted-foreground hover:bg-accent hover:text-foreground disabled:opacity-50"
                          >
                            <Play className="h-3.5 w-3.5" />
                          </button>
                        )}
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
    </div>
  );
}
