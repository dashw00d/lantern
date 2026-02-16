import { StatusBadge } from './StatusBadge';
import type { HealthStatus } from '../../types';

interface HealthStripProps {
  health: HealthStatus | null;
  daemonConnected: boolean;
}

export function HealthStrip({ health, daemonConnected }: HealthStripProps) {
  if (!daemonConnected) {
    return (
      <div className="flex items-center gap-3 rounded-lg border border-red-500/20 bg-red-500/5 p-3">
        <span className="text-sm font-medium text-red-400">
          Daemon not connected
        </span>
        <span className="text-xs text-muted-foreground">
          Start with: sudo systemctl start lantern
        </span>
      </div>
    );
  }

  if (!health) {
    return (
      <div className="flex items-center gap-3 rounded-lg border border-border bg-card p-3">
        <span className="text-sm text-muted-foreground">
          Loading health status...
        </span>
      </div>
    );
  }

  const components = [
    { label: 'DNS', ...health.dns },
    { label: 'Caddy', ...health.caddy },
    { label: 'TLS', ...health.tls },
    { label: 'Daemon', ...health.daemon },
  ];

  return (
    <div className="flex items-center gap-3 rounded-lg border border-border bg-card p-3">
      {components.map((comp) => (
        <div key={comp.label} className="flex items-center gap-2" aria-label={`${comp.label}: ${comp.status}`}>
          <span className="text-xs text-muted-foreground">{comp.label}</span>
          <StatusBadge status={comp.status} />
        </div>
      ))}
    </div>
  );
}
