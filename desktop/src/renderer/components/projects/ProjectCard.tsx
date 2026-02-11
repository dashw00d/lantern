import { Link } from 'react-router-dom';
import { Play, Square, RotateCw, ExternalLink, Copy } from 'lucide-react';
import { cn } from '../../lib/utils';
import { StatusBadge } from '../common/StatusBadge';
import { TypeBadge } from '../common/TypeBadge';
import type { Project } from '../../types';

interface ProjectCardProps {
  project: Project;
  onActivate: (name: string) => void;
  onDeactivate: (name: string) => void;
  onRestart: (name: string) => void;
}

export function ProjectCard({
  project,
  onActivate,
  onDeactivate,
  onRestart,
}: ProjectCardProps) {
  const isRunning = project.status === 'running';
  const isBusy =
    project.status === 'starting' || project.status === 'stopping';
  const url = `https://${project.domain}`;

  const copyUrl = () => {
    navigator.clipboard.writeText(url);
  };

  return (
    <div className="group rounded-lg border border-border bg-card p-4 transition-colors hover:border-primary/30">
      <div className="flex items-start justify-between">
        <Link
          to={`/projects/${encodeURIComponent(project.name)}`}
          className="flex-1 min-w-0"
        >
          <h3 className="font-semibold text-card-foreground truncate group-hover:text-primary transition-colors">
            {project.name}
          </h3>
          <p className="mt-1 text-xs text-muted-foreground truncate">
            {project.path}
          </p>
        </Link>
        <StatusBadge status={project.status} />
      </div>

      <div className="mt-3 flex items-center gap-2">
        <TypeBadge type={project.type} />
        {project.domain && (
          <span className="text-xs text-muted-foreground truncate">
            {project.domain}
          </span>
        )}
      </div>

      <div className="mt-4 flex items-center justify-between">
        <div className="flex items-center gap-1">
          {isRunning ? (
            <>
              <button
                onClick={() => onDeactivate(project.name)}
                disabled={isBusy}
                className="inline-flex h-8 w-8 items-center justify-center rounded-md text-muted-foreground hover:bg-accent hover:text-foreground disabled:opacity-50"
                title="Stop"
              >
                <Square className="h-4 w-4" />
              </button>
              <button
                onClick={() => onRestart(project.name)}
                disabled={isBusy}
                className="inline-flex h-8 w-8 items-center justify-center rounded-md text-muted-foreground hover:bg-accent hover:text-foreground disabled:opacity-50"
                title="Restart"
              >
                <RotateCw className="h-4 w-4" />
              </button>
            </>
          ) : (
            <button
              onClick={() => onActivate(project.name)}
              disabled={isBusy}
              className="inline-flex h-8 w-8 items-center justify-center rounded-md text-muted-foreground hover:bg-accent hover:text-foreground disabled:opacity-50"
              title="Start"
            >
              <Play className="h-4 w-4" />
            </button>
          )}
        </div>

        {isRunning && (
          <div className="flex items-center gap-1">
            <button
              onClick={copyUrl}
              className="inline-flex h-8 w-8 items-center justify-center rounded-md text-muted-foreground hover:bg-accent hover:text-foreground"
              title="Copy URL"
            >
              <Copy className="h-3.5 w-3.5" />
            </button>
            <a
              href={url}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex h-8 w-8 items-center justify-center rounded-md text-muted-foreground hover:bg-accent hover:text-foreground"
              title="Open in browser"
            >
              <ExternalLink className="h-3.5 w-3.5" />
            </a>
          </div>
        )}
      </div>
    </div>
  );
}
