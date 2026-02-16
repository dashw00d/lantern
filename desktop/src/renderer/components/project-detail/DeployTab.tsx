import { useState } from 'react';
import { Play, Square, RotateCw, FileText, RefreshCw, Rocket } from 'lucide-react';
import { cn } from '../../lib/utils';
import { api } from '../../api/client';
import { useAppStore } from '../../stores/appStore';
import { Button } from '../ui/Button';
import { Card, CardContent } from '../ui/Card';
import type { TabProps } from './types';

export function DeployTab({ project }: TabProps) {
  const addToast = useAppStore((s) => s.addToast);
  const [output, setOutput] = useState<string | null>(null);
  const [running, setRunning] = useState(false);
  const deploy = project.deploy || {};

  const runDeploy = async (action: 'start' | 'stop' | 'restart') => {
    setRunning(true);
    setOutput(null);
    try {
      const res = action === 'start'
        ? await api.deployStart(project.name)
        : action === 'stop'
          ? await api.deployStop(project.name)
          : await api.deployRestart(project.name);
      setOutput(res.data.output);
      addToast({ type: 'success', message: `Deploy ${action} completed` });
    } catch (err) {
      setOutput(`Error: ${err instanceof Error ? err.message : 'Unknown error'}`);
      addToast({ type: 'error', message: `Deploy ${action} failed` });
    } finally {
      setRunning(false);
    }
  };

  const readDeployOutput = async (action: 'logs' | 'status') => {
    setRunning(true);
    setOutput(null);
    try {
      const res =
        action === 'logs'
          ? await api.deployLogs(project.name)
          : await api.deployStatus(project.name);
      setOutput(res.data.output);
      addToast({ type: 'success', message: `Deploy ${action} fetched` });
    } catch (err) {
      setOutput(`Error: ${err instanceof Error ? err.message : 'Unknown error'}`);
      addToast({ type: 'error', message: `Deploy ${action} failed` });
    } finally {
      setRunning(false);
    }
  };

  return (
    <div className="space-y-4">
      <Card>
        <CardContent>
          <h3 className="text-sm font-semibold mb-3 flex items-center gap-2">
            <Rocket className="h-4 w-4" />
            Deploy Commands
          </h3>
          <p className="mb-4 text-xs text-muted-foreground">
            Production deploy commands from lantern.yaml (separate from local dev Start/Stop).
          </p>

          <dl className="space-y-2 text-sm">
            {Object.entries(deploy).map(([key, value]) => (
              <div key={key} className="flex items-center justify-between">
                <dt className="text-muted-foreground capitalize">{key}</dt>
                <dd className="font-mono text-xs bg-muted px-2 py-1 rounded">{value as string}</dd>
              </div>
            ))}
          </dl>

          <div className="mt-4 flex items-center gap-2">
            {deploy.start && (
              <Button
                variant="primary"
                size="sm"
                onClick={() => runDeploy('start')}
                disabled={running}
              >
                <Play className="h-3 w-3" />
                Start
              </Button>
            )}
            {deploy.stop && (
              <Button
                variant="destructive"
                size="sm"
                onClick={() => runDeploy('stop')}
                disabled={running}
              >
                <Square className="h-3 w-3" />
                Stop
              </Button>
            )}
            {deploy.restart && (
              <Button
                variant="secondary"
                size="sm"
                onClick={() => runDeploy('restart')}
                disabled={running}
              >
                <RotateCw className="h-3 w-3" />
                Restart
              </Button>
            )}
            {deploy.logs && (
              <Button
                variant="ghost"
                size="sm"
                onClick={() => readDeployOutput('logs')}
                disabled={running}
              >
                <FileText className="h-3 w-3" />
                Logs
              </Button>
            )}
            {deploy.status && (
              <Button
                variant="ghost"
                size="sm"
                onClick={() => readDeployOutput('status')}
                disabled={running}
              >
                <RefreshCw className={cn('h-3 w-3', running && 'animate-spin')} />
                Status
              </Button>
            )}
          </div>

          {output && (
            <pre className="mt-4 rounded-md bg-muted p-3 text-xs font-mono overflow-auto max-h-[300px] whitespace-pre-wrap">
              {output}
            </pre>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
