import { useEffect, useCallback, useRef } from 'react';
import { useAppStore } from '../stores/appStore';
import { joinChannel, leaveChannel } from '../api/socket';
import type { LogEntry } from '../types';

export function useLogs(projectName: string) {
  const logs = useAppStore((s) => s.logs[projectName] || []);
  const appendLog = useAppStore((s) => s.appendLog);
  const clearLogs = useAppStore((s) => s.clearLogs);
  const channelTopic = `project:${projectName}`;

  useEffect(() => {
    const channel = joinChannel(channelTopic);

    channel.on('log', (payload: LogEntry) => {
      appendLog(projectName, payload);
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
