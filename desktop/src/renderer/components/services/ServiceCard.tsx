import { Power, ExternalLink } from 'lucide-react';
import { cn } from '../../lib/utils';
import { StatusBadge } from '../common/StatusBadge';
import type { Service } from '../../types';

interface ServiceCardProps {
  service: Service;
  onStart: (name: string) => void;
  onStop: (name: string) => void;
}

export function ServiceCard({ service, onStart, onStop }: ServiceCardProps) {
  const isRunning = service.status === 'running';

  return (
    <div className="rounded-lg border border-border bg-card p-4">
      <div className="flex items-start justify-between">
        <div>
          <h3 className="font-semibold capitalize text-card-foreground">
            {service.name}
          </h3>
          {service.ports && Object.keys(service.ports).length > 0 && (
            <p className="mt-1 text-xs text-muted-foreground">
              {Object.entries(service.ports)
                .map(([label, port]) => `${label}: ${port}`)
                .join(', ')}
            </p>
          )}
        </div>
        <StatusBadge status={service.status} />
      </div>

      {service.credentials && (
        <div className="mt-3 space-y-1">
          {Object.entries(service.credentials).map(([key, value]) => (
            <div key={key} className="flex items-center gap-2 text-xs">
              <span className="text-muted-foreground">{key}:</span>
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-foreground">
                {value}
              </code>
            </div>
          ))}
        </div>
      )}

      <div className="mt-4 flex items-center justify-between">
        <button
          onClick={() => (isRunning ? onStop(service.name) : onStart(service.name))}
          className={cn(
            'inline-flex items-center gap-2 rounded-md px-3 py-1.5 text-sm font-medium transition-colors',
            isRunning
              ? 'bg-destructive/10 text-destructive hover:bg-destructive/20'
              : 'bg-primary/10 text-primary hover:bg-primary/20'
          )}
        >
          <Power className="h-3.5 w-3.5" />
          {isRunning ? 'Stop' : 'Start'}
        </button>

        {isRunning && service.ui_url && (
          <a
            href={service.ui_url}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1.5 text-xs text-muted-foreground hover:text-foreground"
          >
            Open UI
            <ExternalLink className="h-3 w-3" />
          </a>
        )}
      </div>
    </div>
  );
}
