import { cn } from '../../lib/utils';
import type { ProjectType } from '../../types';

const typeStyles: Record<ProjectType, string> = {
  php: 'bg-indigo-500/10 text-indigo-400 border-indigo-500/20',
  proxy: 'bg-cyan-500/10 text-cyan-400 border-cyan-500/20',
  static: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20',
  unknown: 'bg-muted text-muted-foreground border-border',
};

const typeLabels: Record<ProjectType, string> = {
  php: 'PHP',
  proxy: 'Proxy',
  static: 'Static',
  unknown: 'Unknown',
};

interface TypeBadgeProps {
  type: ProjectType;
  className?: string;
}

export function TypeBadge({ type, className }: TypeBadgeProps) {
  return (
    <span
      aria-label={`Type: ${typeLabels[type] || type}`}
      className={cn(
        'inline-flex items-center rounded-full border px-2 py-0.5 text-xs font-medium',
        typeStyles[type] || typeStyles.unknown,
        className
      )}
    >
      {typeLabels[type] || type}
    </span>
  );
}
