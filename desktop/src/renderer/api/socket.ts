import { Socket, Channel } from 'phoenix';

const SOCKET_URL = 'ws://127.0.0.1:4777/socket';

let socket: Socket | null = null;
const channels = new Map<string, Channel>();

export function getSocket(): Socket {
  if (!socket) {
    socket = new Socket(SOCKET_URL, {
      reconnectAfterMs: (tries: number) =>
        [1000, 2000, 5000, 10000][Math.min(tries - 1, 3)],
    });
    socket.connect();
  }
  return socket;
}

export function joinChannel(
  topic: string,
  params: Record<string, unknown> = {}
): Channel {
  const existing = channels.get(topic);
  if (existing) return existing;

  const s = getSocket();
  const channel = s.channel(topic, params);

  channel
    .join()
    .receive('ok', () => {
      console.log(`Joined channel: ${topic}`);
    })
    .receive('error', (resp: unknown) => {
      console.error(`Failed to join channel ${topic}:`, resp);
    });

  channels.set(topic, channel);
  return channel;
}

export function leaveChannel(topic: string): void {
  const channel = channels.get(topic);
  if (channel) {
    channel.leave();
    channels.delete(topic);
  }
}

export function disconnectSocket(): void {
  if (socket) {
    socket.disconnect();
    socket = null;
  }
  channels.clear();
}
