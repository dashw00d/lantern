import { useEffect, useRef } from 'react';
import { Trash2 } from 'lucide-react';
import { cn } from '../../lib/utils';
import type { LogEntry } from '../../types';

interface LogViewerProps {
  logs: LogEntry[];
  onClear: () => void;
  className?: string;
}

export function LogViewer({ logs, onClear, className }: LogViewerProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const shouldAutoScroll = useRef(true);

  useEffect(() => {
    if (shouldAutoScroll.current && containerRef.current) {
      containerRef.current.scrollTop = containerRef.current.scrollHeight;
    }
  }, [logs]);

  const handleScroll = () => {
    if (!containerRef.current) return;
    const { scrollTop, scrollHeight, clientHeight } = containerRef.current;
    shouldAutoScroll.current = scrollHeight - scrollTop - clientHeight < 50;
  };

  return (
    <div className={cn('flex flex-col rounded-lg border border-border', className)}>
      <div className="flex items-center justify-between border-b border-border px-3 py-2">
        <span className="text-xs text-muted-foreground">
          {logs.length} lines
        </span>
        <button
          onClick={onClear}
          className="inline-flex items-center gap-1.5 rounded-md px-2 py-1 text-xs text-muted-foreground hover:bg-accent hover:text-foreground"
        >
          <Trash2 className="h-3 w-3" />
          Clear
        </button>
      </div>
      <div
        ref={containerRef}
        onScroll={handleScroll}
        className="flex-1 overflow-y-auto bg-background p-3 font-mono text-xs"
      >
        {logs.length === 0 ? (
          <p className="text-muted-foreground">No logs yet...</p>
        ) : (
          logs.map((entry, i) => (
            <div
              key={i}
              className={cn(
                'whitespace-pre-wrap break-all py-0.5',
                entry.stream === 'stderr' ? 'text-red-400' : 'text-foreground'
              )}
            >
              <span className="select-none text-muted-foreground/50 mr-2">
                {new Date(entry.timestamp).toLocaleTimeString()}
              </span>
              {entry.line}
            </div>
          ))
        )}
      </div>
    </div>
  );
}
