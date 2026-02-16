import { useEffect, useCallback } from 'react';
import { useAppStore } from '../stores/appStore';
import { joinChannel, leaveChannel } from '../api/socket';
import type { LogEntry } from '../types';

const EMPTY_LOGS: LogEntry[] = [];

export function useLogs(projectName: string, enabled: boolean = true) {
  const logs = useAppStore((s) => s.logs[projectName] ?? EMPTY_LOGS);
  const channelTopic = `project:${projectName}`;

  useEffect(() => {
    if (!enabled || !projectName) {
      return;
    }

    const channel = joinChannel(channelTopic);

    channel.on('log_line', (payload: { line?: string }) => {
      if (!payload.line) return;

      useAppStore.getState().appendLog(projectName, {
        timestamp: new Date().toISOString(),
        stream: 'stdout',
        line: payload.line,
      });
    });

    return () => {
      leaveChannel(channelTopic);
    };
  }, [enabled, projectName, channelTopic]);

  const clear = useCallback(() => {
    useAppStore.getState().clearLogs(projectName);
  }, [projectName]);

  return { logs, clear };
}
