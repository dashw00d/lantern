import { Globe } from 'lucide-react';
import { cn } from '../../lib/utils';
import { Card, CardHeader, CardTitle, CardContent } from '../ui/Card';
import type { TabProps } from './types';

export function EndpointsTab({ project }: TabProps) {
  const endpoints = project.endpoints || [];

  const riskColor = (risk?: string) => {
    switch (risk) {
      case 'high': return 'text-red-400';
      case 'medium': return 'text-yellow-400';
      case 'low': return 'text-green-400';
      default: return 'text-muted-foreground';
    }
  };

  const methodColor = (method: string) => {
    switch (method.toUpperCase()) {
      case 'GET': return 'text-blue-400';
      case 'POST': return 'text-green-400';
      case 'PUT': return 'text-yellow-400';
      case 'PATCH': return 'text-orange-400';
      case 'DELETE': return 'text-red-400';
      default: return 'text-muted-foreground';
    }
  };

  return (
    <div className="space-y-4">
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Globe className="h-4 w-4" />
            API Endpoints ({endpoints.length})
          </CardTitle>
        </CardHeader>
        {endpoints.length === 0 ? (
          <CardContent>
            <p className="text-sm text-muted-foreground">No endpoints configured</p>
          </CardContent>
        ) : (
          <div className="divide-y divide-border">
            {endpoints.map((ep, i) => (
              <div key={i} className="px-4 py-3 flex items-center gap-4">
                <span className={cn('font-mono text-xs font-bold w-16', methodColor(ep.method))}>
                  {ep.method}
                </span>
                <span className="font-mono text-sm flex-1">{ep.path}</span>
                {ep.description && (
                  <span className="text-sm text-muted-foreground">{ep.description}</span>
                )}
                {ep.category && (
                  <span className="rounded bg-muted px-2 py-0.5 text-xs">{ep.category}</span>
                )}
                {ep.risk && (
                  <span className={cn('text-xs font-medium', riskColor(ep.risk))}>
                    {ep.risk}
                  </span>
                )}
              </div>
            ))}
          </div>
        )}
      </Card>
    </div>
  );
}
