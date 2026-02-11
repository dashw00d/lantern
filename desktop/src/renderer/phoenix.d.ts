declare module 'phoenix' {
  export class Socket {
    constructor(endPoint: string, opts?: Record<string, unknown>);
    connect(): void;
    disconnect(): void;
    channel(topic: string, params?: Record<string, unknown>): Channel;
    onOpen(callback: () => void): void;
    onClose(callback: () => void): void;
    onError(callback: (error: unknown) => void): void;
  }

  export class Channel {
    join(): Push;
    leave(): Push;
    on(event: string, callback: (payload: any) => void): number;
    off(event: string, ref?: number): void;
    push(event: string, payload?: Record<string, unknown>): Push;
  }

  export class Push {
    receive(status: string, callback: (response: unknown) => void): Push;
  }
}
