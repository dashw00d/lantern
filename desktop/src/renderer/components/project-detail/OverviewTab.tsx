import { ExternalLink, Copy } from 'lucide-react';
import { cn } from '../../lib/utils';
import { Card, CardContent } from '../ui/Card';
import { TypeBadge } from '../common/TypeBadge';
import type { TabProps } from './types';

export function OverviewTab({ project }: TabProps) {
  const hasDomain = Boolean(project.domain);
  const url = hasDomain ? `https://${project.domain}` : '';
  const detection = project.detection || { confidence: 'low', source: 'auto' };
  const features = project.features || {};

  return (
    <div className="grid grid-cols-2 gap-6">
      <div className="space-y-4">
        <Card>
          <CardContent>
            <h3 className="text-sm font-semibold mb-3">Details</h3>
            <dl className="space-y-2 text-sm">
              <div className="flex justify-between">
                <dt className="text-muted-foreground">Domain</dt>
                <dd className="flex items-center gap-1">
                  {project.domain || 'N/A'}
                  <button
                    onClick={() => hasDomain && navigator.clipboard.writeText(url)}
                    disabled={!hasDomain}
                    className="text-muted-foreground hover:text-foreground"
                  >
                    <Copy className="h-3 w-3" />
                  </button>
                </dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-muted-foreground">Port</dt>
                <dd>{project.port || 'N/A'}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-muted-foreground">Type</dt>
                <dd><TypeBadge type={project.type || 'unknown'} /></dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-muted-foreground">Detection</dt>
                <dd className="capitalize">
                  {detection.confidence} ({detection.source})
                </dd>
              </div>
              {project.base_url && (
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">Base URL</dt>
                  <dd>
                    <a href={project.base_url} target="_blank" rel="noopener noreferrer" className="text-primary hover:underline flex items-center gap-1">
                      {project.base_url}
                      <ExternalLink className="h-3 w-3" />
                    </a>
                  </dd>
                </div>
              )}
              {project.upstream_url && (
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">Upstream</dt>
                  <dd>
                    <a href={project.upstream_url} target="_blank" rel="noopener noreferrer" className="text-primary hover:underline flex items-center gap-1">
                      {project.upstream_url}
                      <ExternalLink className="h-3 w-3" />
                    </a>
                  </dd>
                </div>
              )}
              {project.repo_url && (
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">Repository</dt>
                  <dd>
                    <a href={project.repo_url} target="_blank" rel="noopener noreferrer" className="text-primary hover:underline flex items-center gap-1">
                      {project.repo_url.replace(/^https?:\/\//, '')}
                      <ExternalLink className="h-3 w-3" />
                    </a>
                  </dd>
                </div>
              )}
              {project.template && (
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">Template</dt>
                  <dd>{project.template}</dd>
                </div>
              )}
              {project.pid && (
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">PID</dt>
                  <dd className="font-mono">{project.pid}</dd>
                </div>
              )}
            </dl>
          </CardContent>
        </Card>
      </div>

      <div className="space-y-4">
        <Card>
          <CardContent>
            <h3 className="text-sm font-semibold mb-3">Features</h3>
            <div className="space-y-2">
              {Object.entries(features).map(([key, value]) => (
                <div key={key} className="flex items-center justify-between text-sm">
                  <span className="text-muted-foreground capitalize">
                    {key.replace(/_/g, ' ')}
                  </span>
                  <span
                    className={cn(
                      'text-xs font-medium',
                      value ? 'text-green-500' : 'text-muted-foreground'
                    )}
                  >
                    {value ? 'Enabled' : 'Disabled'}
                  </span>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
