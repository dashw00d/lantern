import { cn } from '../../lib/utils';
import type { ProjectStatus, ServiceStatus, ComponentHealth } from '../../types';

type Status = ProjectStatus | ServiceStatus | ComponentHealth['status'];

const statusStyles: Record<string, string> = {
  running: 'bg-green-500/10 text-green-500 border-green-500/20',
  ok: 'bg-green-500/10 text-green-500 border-green-500/20',
  stopped: 'bg-muted text-muted-foreground border-border',
  starting: 'bg-blue-500/10 text-blue-500 border-blue-500/20',
  stopping: 'bg-yellow-500/10 text-yellow-500 border-yellow-500/20',
  warning: 'bg-yellow-500/10 text-yellow-500 border-yellow-500/20',
  error: 'bg-red-500/10 text-red-500 border-red-500/20',
  needs_config: 'bg-orange-500/10 text-orange-500 border-orange-500/20',
  unknown: 'bg-muted text-muted-foreground border-border',
};

const statusLabels: Record<string, string> = {
  running: 'Running',
  ok: 'OK',
  stopped: 'Stopped',
  starting: 'Starting',
  stopping: 'Stopping',
  warning: 'Warning',
  error: 'Error',
  needs_config: 'Needs Config',
  unknown: 'Unknown',
};

interface StatusBadgeProps {
  status: Status;
  className?: string;
}

export function StatusBadge({ status, className }: StatusBadgeProps) {
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1.5 rounded-full border px-2.5 py-0.5 text-xs font-medium',
        statusStyles[status] || statusStyles.unknown,
        className
      )}
    >
      <span
        className={cn(
          'h-1.5 w-1.5 rounded-full',
          status === 'running' || status === 'ok'
            ? 'bg-green-500'
            : status === 'starting'
              ? 'bg-blue-500 animate-pulse'
              : status === 'stopping' || status === 'warning'
                ? 'bg-yellow-500'
                : status === 'error'
                  ? 'bg-red-500'
                  : status === 'needs_config'
                    ? 'bg-orange-500'
                    : 'bg-muted-foreground'
        )}
      />
      {statusLabels[status] || status}
    </span>
  );
}
