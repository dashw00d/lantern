// Core types matching the Phoenix API responses

export type ProjectType = 'php' | 'proxy' | 'static' | 'unknown';

export type ProjectStatus =
  | 'stopped'
  | 'starting'
  | 'running'
  | 'stopping'
  | 'error'
  | 'needs_config';

export type DetectionConfidence = 'high' | 'medium' | 'low';

export interface Project {
  name: string;
  path: string;
  domain: string;
  type: ProjectType;
  status: ProjectStatus;
  port: number | null;
  run_cmd: string | null;
  run_cwd: string | null;
  run_env: Record<string, string>;
  root: string | null;
  features: {
    mailpit?: boolean;
    auto_start?: boolean;
    auto_open_browser?: boolean;
  };
  detection: {
    confidence: DetectionConfidence;
    source: 'auto' | 'manual' | 'config';
  };
  pid: number | null;
  template: string | null;
}

export type ServiceStatus = 'running' | 'stopped' | 'error' | 'unknown';

export interface Service {
  name: string;
  status: ServiceStatus;
  ports: Record<string, number>;
  ui_url: string | null;
  credentials: Record<string, string> | null;
}

export interface HealthStatus {
  dns: ComponentHealth;
  caddy: ComponentHealth;
  tls: ComponentHealth;
  daemon: ComponentHealth;
}

export interface ComponentHealth {
  status: 'ok' | 'warning' | 'error' | 'unknown';
  message: string;
}

export interface Settings {
  workspace_roots: string[];
  tld: string;
  php_fpm_socket: string;
  caddy_mode: 'files' | 'admin_api';
  default_template: string | null;
  active_profile: string | null;
}

export interface Template {
  name: string;
  type: ProjectType;
  run_cmd: string | null;
  root: string | null;
  features: Record<string, boolean>;
  builtin: boolean;
}

export interface Profile {
  name: string;
  services: string[];
  auto_start_projects: string[];
  env: Record<string, string>;
  port_range: [number, number];
}

// API response envelope
export interface ApiResponse<T> {
  data: T;
  meta?: Record<string, unknown>;
}

export interface ApiError {
  error: string;
  message: string;
}

export interface LogEntry {
  timestamp: string;
  stream: 'stdout' | 'stderr';
  line: string;
}
