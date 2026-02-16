import type {
  ApiResponse,
  Project,
  Service,
  HealthStatus,
  Settings,
  Template,
  Profile,
  DocEntry,
  ToolSummary,
  ToolDetail,
  ToolDoc,
  EndpointEntry,
  ProjectHealthStatus,
  DependencyGraph,
  PortAssignment,
} from '../types';

const BASE_URL = 'http://127.0.0.1:4777';

class LanternClient {
  private baseUrl: string;

  constructor(baseUrl: string = BASE_URL) {
    this.baseUrl = baseUrl;
  }

  private async request<T>(
    method: string,
    path: string,
    body?: unknown
  ): Promise<T> {
    const res = await fetch(`${this.baseUrl}${path}`, {
      method,
      headers: { 'Content-Type': 'application/json' },
      body: body ? JSON.stringify(body) : undefined,
    });

    if (!res.ok) {
      const error = await res.json().catch(() => ({
        error: 'unknown',
        message: res.statusText,
      }));
      throw new Error(error.message || `HTTP ${res.status}`);
    }

    return res.json();
  }

  private buildPath(
    path: string,
    query?: Record<string, string | number | boolean | null | undefined>
  ): string {
    if (!query) return path;

    const params = new URLSearchParams();

    Object.entries(query).forEach(([key, value]) => {
      if (value === undefined || value === null) return;
      params.set(key, String(value));
    });

    const queryString = params.toString();
    return queryString === '' ? path : `${path}?${queryString}`;
  }

  private encodeRelativePath(path: string): string {
    return path
      .split('/')
      .filter((segment) => segment.length > 0)
      .map((segment) => encodeURIComponent(segment))
      .join('/');
  }

  // Projects
  async listProjects(options?: {
    includeHidden?: boolean;
  }): Promise<ApiResponse<Project[]>> {
    return this.request(
      'GET',
      this.buildPath('/api/projects', {
        include_hidden: options?.includeHidden ? 'true' : undefined,
      })
    );
  }

  async getProject(name: string): Promise<ApiResponse<Project>> {
    return this.request('GET', `/api/projects/${encodeURIComponent(name)}`);
  }

  async createProject(
    project: Partial<Project> & { name: string; path: string }
  ): Promise<ApiResponse<Project>> {
    return this.request('POST', '/api/projects', project);
  }

  async activateProject(name: string): Promise<ApiResponse<Project>> {
    return this.request(
      'POST',
      `/api/projects/${encodeURIComponent(name)}/activate`
    );
  }

  async deactivateProject(name: string): Promise<ApiResponse<Project>> {
    return this.request(
      'POST',
      `/api/projects/${encodeURIComponent(name)}/deactivate`
    );
  }

  async restartProject(name: string): Promise<ApiResponse<Project>> {
    return this.request(
      'POST',
      `/api/projects/${encodeURIComponent(name)}/restart`
    );
  }

  async updateProject(
    name: string,
    config: Partial<Project> & { new_name?: string }
  ): Promise<ApiResponse<Project>> {
    return this.request(
      'PUT',
      `/api/projects/${encodeURIComponent(name)}`,
      config
    );
  }

  async patchProject(
    name: string,
    config: Partial<Project> & { new_name?: string }
  ): Promise<ApiResponse<Project>> {
    return this.request(
      'PATCH',
      `/api/projects/${encodeURIComponent(name)}`,
      config
    );
  }

  async deleteProject(name: string): Promise<ApiResponse<{ deleted: string }>> {
    return this.request(
      'DELETE',
      `/api/projects/${encodeURIComponent(name)}`
    );
  }

  async scanProjects(options?: {
    includeHidden?: boolean;
  }): Promise<ApiResponse<Project[]>> {
    return this.request(
      'POST',
      this.buildPath('/api/projects/scan', {
        include_hidden: options?.includeHidden ? 'true' : undefined,
      })
    );
  }

  // Tools
  async listTools(options?: {
    includeHidden?: boolean;
    kind?: string;
    kinds?: string[];
  }): Promise<ApiResponse<ToolSummary[]>> {
    return this.request(
      'GET',
      this.buildPath('/api/tools', {
        include_hidden: options?.includeHidden ? 'true' : undefined,
        kind: options?.kind,
        kinds: options?.kinds?.join(','),
      })
    );
  }

  async getTool(
    id: string,
    options?: { includeHidden?: boolean }
  ): Promise<ApiResponse<ToolDetail>> {
    return this.request(
      'GET',
      this.buildPath(`/api/tools/${encodeURIComponent(id)}`, {
        include_hidden: options?.includeHidden ? 'true' : undefined,
      })
    );
  }

  async getToolDocs(
    id: string,
    options?: { includeHidden?: boolean }
  ): Promise<ApiResponse<{ id: string; name: string; docs: ToolDoc[] }>> {
    return this.request(
      'GET',
      this.buildPath(`/api/tools/${encodeURIComponent(id)}/docs`, {
        include_hidden: options?.includeHidden ? 'true' : undefined,
      })
    );
  }

  async getProjectEndpoints(
    name: string
  ): Promise<ApiResponse<EndpointEntry[]>> {
    return this.request(
      'GET',
      `/api/projects/${encodeURIComponent(name)}/endpoints`
    );
  }

  // Deploy
  async deployStart(
    name: string
  ): Promise<ApiResponse<{ project: string; command: string; output: string }>> {
    return this.request(
      'POST',
      `/api/projects/${encodeURIComponent(name)}/deploy/start`
    );
  }

  async deployStop(
    name: string
  ): Promise<ApiResponse<{ project: string; command: string; output: string }>> {
    return this.request(
      'POST',
      `/api/projects/${encodeURIComponent(name)}/deploy/stop`
    );
  }

  async deployRestart(
    name: string
  ): Promise<ApiResponse<{ project: string; command: string; output: string }>> {
    return this.request(
      'POST',
      `/api/projects/${encodeURIComponent(name)}/deploy/restart`
    );
  }

  async deployLogs(
    name: string
  ): Promise<ApiResponse<{ project: string; output: string }>> {
    return this.request(
      'GET',
      `/api/projects/${encodeURIComponent(name)}/deploy/logs`
    );
  }

  async deployStatus(
    name: string
  ): Promise<ApiResponse<{ project: string; output: string }>> {
    return this.request(
      'GET',
      `/api/projects/${encodeURIComponent(name)}/deploy/status`
    );
  }

  // Docs
  async listDocs(name: string): Promise<ApiResponse<DocEntry[]>> {
    return this.request(
      'GET',
      `/api/projects/${encodeURIComponent(name)}/docs`
    );
  }

  async getDoc(name: string, filename: string): Promise<string> {
    const safeFilename = this.encodeRelativePath(filename);
    const res = await fetch(
      `${this.baseUrl}/api/projects/${encodeURIComponent(name)}/docs/${safeFilename}`
    );
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return res.text();
  }

  // Health
  async getProjectHealthAll(): Promise<
    ApiResponse<Record<string, ProjectHealthStatus>>
  > {
    return this.request('GET', '/api/health');
  }

  async getProjectHealth(
    name: string
  ): Promise<ApiResponse<ProjectHealthStatus>> {
    return this.request(
      'GET',
      `/api/projects/${encodeURIComponent(name)}/health`
    );
  }

  async checkProjectHealth(
    name: string
  ): Promise<ApiResponse<ProjectHealthStatus>> {
    return this.request(
      'POST',
      `/api/projects/${encodeURIComponent(name)}/health/check`
    );
  }

  // Infrastructure
  async getPorts(): Promise<ApiResponse<Record<string, PortAssignment>>> {
    return this.request('GET', '/api/ports');
  }

  async getDependencies(): Promise<ApiResponse<DependencyGraph>> {
    return this.request('GET', '/api/dependencies');
  }

  async getProjectDependencies(
    name: string
  ): Promise<ApiResponse<{ project: string; depends_on: string[] }>> {
    return this.request(
      'GET',
      `/api/projects/${encodeURIComponent(name)}/dependencies`
    );
  }

  async getProjectDependents(
    name: string
  ): Promise<ApiResponse<{ project: string; depended_by: string[] }>> {
    return this.request(
      'GET',
      `/api/projects/${encodeURIComponent(name)}/dependents`
    );
  }

  // Services
  async listServices(): Promise<ApiResponse<Service[]>> {
    return this.request('GET', '/api/services');
  }

  async startService(name: string): Promise<ApiResponse<Service>> {
    return this.request(
      'POST',
      `/api/services/${encodeURIComponent(name)}/start`
    );
  }

  async stopService(name: string): Promise<ApiResponse<Service>> {
    return this.request(
      'POST',
      `/api/services/${encodeURIComponent(name)}/stop`
    );
  }

  async getServiceStatus(name: string): Promise<ApiResponse<Service>> {
    return this.request(
      'GET',
      `/api/services/${encodeURIComponent(name)}/status`
    );
  }

  // System
  async getHealth(): Promise<ApiResponse<HealthStatus>> {
    return this.request('GET', '/api/system/health');
  }

  async initSystem(): Promise<ApiResponse<{ status: string }>> {
    return this.request('POST', '/api/system/init');
  }

  async getSettings(): Promise<ApiResponse<Settings>> {
    return this.request('GET', '/api/system/settings');
  }

  async updateSettings(
    settings: Partial<Settings>
  ): Promise<ApiResponse<Settings>> {
    return this.request('PUT', '/api/system/settings', settings);
  }

  // Templates
  async listTemplates(): Promise<ApiResponse<Template[]>> {
    return this.request('GET', '/api/templates');
  }

  async createTemplate(
    template: Omit<Template, 'builtin'>
  ): Promise<ApiResponse<Template>> {
    return this.request('POST', '/api/templates', template);
  }

  async updateTemplate(
    name: string,
    template: Partial<Template>
  ): Promise<ApiResponse<Template>> {
    return this.request(
      'PUT',
      `/api/templates/${encodeURIComponent(name)}`,
      template
    );
  }

  async deleteTemplate(name: string): Promise<void> {
    await this.request(
      'DELETE',
      `/api/templates/${encodeURIComponent(name)}`
    );
  }

  // Profiles
  async listProfiles(): Promise<ApiResponse<Profile[]>> {
    return this.request('GET', '/api/profiles');
  }

  async activateProfile(name: string): Promise<ApiResponse<Profile>> {
    return this.request(
      'POST',
      `/api/profiles/${encodeURIComponent(name)}/activate`
    );
  }
}

export const api = new LanternClient();
