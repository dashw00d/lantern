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

export type ProjectKind =
  | 'service'
  | 'project'
  | 'capability'
  | 'website'
  | 'tool';

export interface DeployConfig {
  start?: string;
  stop?: string;
  restart?: string;
  logs?: string;
  status?: string;
  env_file?: string;
}

export interface DocEntry {
  path: string;
  kind: string;
  source?: 'manual' | 'discovered' | string;
  exists?: boolean;
  size?: number | null;
  mtime?: string | null;
}

export interface EndpointEntry {
  method: string;
  path: string;
  description?: string;
  category?: string;
  risk?: string;
  body_hint?: string;
  source?: 'manual' | 'discovered' | string;
}

export interface DiscoveryMetadata {
  refreshed_at?: string;
  docs?: {
    enabled?: boolean;
    count?: number;
    source_count?: number;
    sources?: string[];
  };
  api?: {
    enabled?: boolean;
    count?: number;
    source_count?: number;
    sources?: string[];
    errors?: { source: string; error: string }[];
  };
}

export interface RoutingConfig {
  aliases?: string[];
  paths?: Record<string, string>;
  websocket?: boolean;
  triggers?: string[];
  risk?: string;
  requires_confirmation?: boolean;
  max_concurrent?: number;
  agents?: string[];
}

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
  // New registry fields
  id: string;
  description: string | null;
  kind: ProjectKind;
  base_url: string | null;
  upstream_url: string | null;
  health_endpoint: string | null;
  repo_url: string | null;
  tags: string[];
  enabled: boolean;
  registered_at: string | null;
  deploy: DeployConfig;
  docs: DocEntry[];
  endpoints: EndpointEntry[];
  docs_auto?: Record<string, unknown>;
  api_auto?: Record<string, unknown>;
  discovered_docs?: DocEntry[];
  discovered_endpoints?: EndpointEntry[];
  docs_available?: DocEntry[];
  endpoints_available?: EndpointEntry[];
  discovery?: DiscoveryMetadata;
  routing: RoutingConfig | null;
  depends_on: string[];
}

export type ServiceStatus = 'running' | 'stopped' | 'error' | 'unknown';

export interface Service {
  name: string;
  status: ServiceStatus;
  ports: Record<string, number>;
  ui_url: string | null;
  health_check_url?: string | null;
  credentials: Record<string, string> | null;
}

export interface ToolSummary {
  id: string;
  name: string;
  kind: ProjectKind;
  description: string | null;
  tags: string[];
  enabled: boolean;
  status: ProjectStatus;
  domain: string | null;
  base_url: string | null;
  upstream_url: string | null;
  health_endpoint: string | null;
  health_status: string;
  requires_confirmation: boolean;
  max_concurrent: number;
  triggers: string[];
  risk: string | null;
  agents: string[];
}

export interface ToolDetail extends ToolSummary {
  path: string;
  repo_path: string;
  run_cmd: string | null;
  endpoints: EndpointEntry[];
  docs: DocEntry[];
  discovered_docs?: DocEntry[];
  docs_available?: DocEntry[];
  docs_paths: string[];
  endpoints_available?: EndpointEntry[];
  discovered_endpoints?: EndpointEntry[];
  docs_auto?: Record<string, unknown>;
  api_auto?: Record<string, unknown>;
  discovery?: DiscoveryMetadata;
  routing: RoutingConfig | null;
  depends_on: string[];
  repo_url: string | null;
}

export interface ToolDoc extends DocEntry {
  content?: string | null;
  error?: string | null;
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

export interface ProjectHealthStatus {
  status: 'healthy' | 'unhealthy' | 'unreachable' | 'error' | 'unknown';
  latency_ms: number | null;
  checked_at: string | null;
  error: string | null;
  history: ProjectHealthEntry[];
}

export interface ProjectHealthEntry {
  status: string;
  latency_ms: number;
  checked_at: string;
  error: string | null;
}

export interface DependencyGraph {
  [projectName: string]: {
    depends_on: string[];
    depended_by: string[];
  };
}

export interface PortAssignment {
  port: number;
  health_status: string;
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
