import { useEffect, useCallback } from 'react';
import { useAppStore } from '../stores/appStore';
import { joinChannel, leaveChannel } from '../api/socket';

export function useLogs(projectName: string) {
  const logs = useAppStore((s) => s.logs[projectName] || []);
  const appendLog = useAppStore((s) => s.appendLog);
  const clearLogs = useAppStore((s) => s.clearLogs);
  const channelTopic = `project:${projectName}`;

  useEffect(() => {
    const channel = joinChannel(channelTopic);

    channel.on('log_line', (payload: { line?: string }) => {
      if (!payload.line) return;

      appendLog(projectName, {
        timestamp: new Date().toISOString(),
        stream: 'stdout',
        line: payload.line,
      });
    });

    return () => {
      leaveChannel(channelTopic);
    };
  }, [projectName, channelTopic, appendLog]);

  const clear = useCallback(() => {
    clearLogs(projectName);
  }, [projectName, clearLogs]);

  return { logs, clear };
}
