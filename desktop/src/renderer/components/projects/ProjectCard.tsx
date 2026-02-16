import { Link } from 'react-router-dom';
import { Play, Square, RotateCw, ExternalLink, Copy } from 'lucide-react';
import { StatusBadge } from '../common/StatusBadge';
import { TypeBadge } from '../common/TypeBadge';
import { Button } from '../ui/Button';
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
  const isHidden = project.enabled === false;
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
        {isHidden && (
          <span className="rounded bg-muted px-1.5 py-0.5 text-xs text-muted-foreground">
            hidden
          </span>
        )}
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
              <Button
                variant="ghost"
                size="icon"
                onClick={() => onDeactivate(project.name)}
                disabled={isBusy}
                title="Stop"
                aria-label="Stop"
              >
                <Square className="h-4 w-4" />
              </Button>
              <Button
                variant="ghost"
                size="icon"
                onClick={() => onRestart(project.name)}
                disabled={isBusy}
                title="Restart"
                aria-label="Restart"
              >
                <RotateCw className="h-4 w-4" />
              </Button>
            </>
          ) : (
            <Button
              variant="ghost"
              size="icon"
              onClick={() => onActivate(project.name)}
              disabled={isBusy || isHidden}
              title="Start"
              aria-label="Start"
            >
              <Play className="h-4 w-4" />
            </Button>
          )}
        </div>

        {isRunning && (
          <div className="flex items-center gap-1">
            <Button
              variant="ghost"
              size="icon"
              onClick={copyUrl}
              title="Copy URL"
              aria-label="Copy URL"
            >
              <Copy className="h-3.5 w-3.5" />
            </Button>
            <a
              href={url}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex h-8 w-8 items-center justify-center rounded-md text-muted-foreground hover:bg-accent hover:text-foreground"
              title="Open in browser"
              aria-label="Open in browser"
            >
              <ExternalLink className="h-3.5 w-3.5" />
            </a>
          </div>
        )}
      </div>
    </div>
  );
}
