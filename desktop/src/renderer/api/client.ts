import type {
  ApiResponse,
  Project,
  Service,
  HealthStatus,
  Settings,
  Template,
  Profile,
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

  // Projects
  async listProjects(): Promise<ApiResponse<Project[]>> {
    return this.request('GET', '/api/projects');
  }

  async getProject(name: string): Promise<ApiResponse<Project>> {
    return this.request('GET', `/api/projects/${encodeURIComponent(name)}`);
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
    config: Partial<Project>
  ): Promise<ApiResponse<Project>> {
    return this.request(
      'PUT',
      `/api/projects/${encodeURIComponent(name)}`,
      config
    );
  }

  async scanProjects(): Promise<ApiResponse<Project[]>> {
    return this.request('POST', '/api/projects/scan');
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
