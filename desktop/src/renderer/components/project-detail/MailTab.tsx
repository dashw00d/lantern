import { ExternalLink } from 'lucide-react';
import { cn } from '../../lib/utils';
import { Card, CardContent } from '../ui/Card';
import type { TabProps } from './types';

export function MailTab({ project }: TabProps) {
  const mailEnabled = Boolean(project.features?.mailpit);

  return (
    <div className="space-y-4">
      <Card>
        <CardContent>
          <h3 className="text-sm font-semibold mb-3">Mail Configuration</h3>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm">Mailpit Integration</p>
              <p className="text-xs text-muted-foreground">
                Capture outgoing mail via SMTP on localhost:1025
              </p>
            </div>
            <span
              className={cn(
                'text-sm font-medium',
                mailEnabled ? 'text-green-500' : 'text-muted-foreground'
              )}
            >
              {mailEnabled ? 'Enabled' : 'Disabled'}
            </span>
          </div>
          {mailEnabled && (
            <div className="mt-4 space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-muted-foreground">SMTP</span>
                <span className="font-mono text-xs">127.0.0.1:1025</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Inbox</span>
                <a
                  href="http://127.0.0.1:8025"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center gap-1 text-primary hover:underline"
                >
                  Open Mailpit
                  <ExternalLink className="h-3 w-3" />
                </a>
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
