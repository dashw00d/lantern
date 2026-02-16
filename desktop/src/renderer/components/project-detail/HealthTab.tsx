import { useEffect, useState } from 'react';
import { Heart, RefreshCw } from 'lucide-react';
import { cn } from '../../lib/utils';
import { api } from '../../api/client';
import { Button } from '../ui/Button';
import { Card, CardContent } from '../ui/Card';
import type { ProjectHealthStatus } from '../../types';
import type { TabProps } from './types';

export function HealthTab({ project }: TabProps) {
  const [health, setHealth] = useState<ProjectHealthStatus | null>(null);
  const [checking, setChecking] = useState(false);

  useEffect(() => {
    api.getProjectHealth(project.name)
      .then((res) => setHealth(res.data))
      .catch((err) => console.warn('Failed to fetch project health:', err));
  }, [project.name]);

  const handleCheck = async () => {
    setChecking(true);
    try {
      const res = await api.checkProjectHealth(project.name);
      setHealth(res.data);
    } catch (err) {
      console.warn('Health check failed:', err);
    } finally {
      setChecking(false);
    }
  };

  const statusColor = (status?: string) => {
    switch (status) {
      case 'healthy': return 'text-green-400';
      case 'unhealthy': return 'text-yellow-400';
      case 'unreachable': return 'text-red-400';
      case 'error': return 'text-red-400';
      default: return 'text-muted-foreground';
    }
  };

  return (
    <div className="space-y-4">
      <Card>
        <CardContent>
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-sm font-semibold flex items-center gap-2">
              <Heart className="h-4 w-4" />
              Health Status
            </h3>
            <Button
              variant="secondary"
              size="sm"
              onClick={handleCheck}
              disabled={checking}
            >
              <RefreshCw className={cn('h-3 w-3', checking && 'animate-spin')} />
              Check Now
            </Button>
          </div>

          {health ? (
            <div className="space-y-4">
              <div className="grid grid-cols-3 gap-4">
                <div className="rounded-md bg-muted p-3">
                  <p className="text-xs text-muted-foreground">Status</p>
                  <p className={cn('text-lg font-bold capitalize', statusColor(health.status))}>
                    {health.status}
                  </p>
                </div>
                <div className="rounded-md bg-muted p-3">
                  <p className="text-xs text-muted-foreground">Latency</p>
                  <p className="text-lg font-bold">
                    {health.latency_ms != null ? `${health.latency_ms}ms` : 'N/A'}
                  </p>
                </div>
                <div className="rounded-md bg-muted p-3">
                  <p className="text-xs text-muted-foreground">Last Checked</p>
                  <p className="text-sm font-medium">
                    {health.checked_at ? new Date(health.checked_at).toLocaleTimeString() : 'Never'}
                  </p>
                </div>
              </div>

              {health.error && (
                <div className="rounded-md bg-red-500/10 p-3 text-sm text-red-400">
                  {health.error}
                </div>
              )}

              {health.history?.length > 0 && (
                <div>
                  <h4 className="text-xs font-semibold text-muted-foreground mb-2">Recent History</h4>
                  <div className="space-y-1">
                    {health.history.map((entry, i) => (
                      <div key={i} className="flex items-center gap-3 text-xs">
                        <span className={cn('font-medium w-20', statusColor(entry.status))}>
                          {entry.status}
                        </span>
                        <span className="text-muted-foreground w-16">{entry.latency_ms}ms</span>
                        <span className="text-muted-foreground">
                          {new Date(entry.checked_at).toLocaleTimeString()}
                        </span>
                        {entry.error && <span className="text-red-400">{entry.error}</span>}
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          ) : (
            <p className="text-sm text-muted-foreground">
              {project.health_endpoint
                ? 'No health data yet. Click "Check Now" to trigger a check.'
                : 'No health endpoint configured for this project.'}
            </p>
          )}

          <div className="mt-4 border-t border-border pt-3">
            <dl className="text-sm space-y-1">
              <div className="flex justify-between">
                <dt className="text-muted-foreground">Endpoint</dt>
                <dd className="font-mono text-xs">{project.health_endpoint || 'Not configured'}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-muted-foreground">Base URL</dt>
                <dd className="font-mono text-xs">{project.base_url || 'Not configured'}</dd>
              </div>
            </dl>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
