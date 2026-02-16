import { create } from 'zustand';
import type {
  Project,
  Service,
  HealthStatus,
  Settings,
  LogEntry,
  ProjectHealthStatus,
  DependencyGraph,
} from '../types';

export interface Toast {
  id: string;
  type: 'success' | 'error' | 'info' | 'warning';
  message: string;
}

interface AppState {
  // Projects
  projects: Project[];
  projectsLoaded: boolean;
  setProjects: (projects: Project[]) => void;
  updateProject: (name: string, updates: Partial<Project>) => void;
  upsertProject: (project: Project) => void;

  // Services
  services: Service[];
  setServices: (services: Service[]) => void;
  updateService: (name: string, updates: Partial<Service>) => void;

  // Health (system-level)
  health: HealthStatus | null;
  setHealth: (health: HealthStatus) => void;

  // Project Health (per-project health checks)
  projectHealth: Record<string, ProjectHealthStatus>;
  setProjectHealth: (health: Record<string, ProjectHealthStatus>) => void;
  updateProjectHealth: (name: string, status: ProjectHealthStatus) => void;

  // Dependency Graph
  dependencyGraph: DependencyGraph;
  setDependencyGraph: (graph: DependencyGraph) => void;

  // Settings
  settings: Settings | null;
  setSettings: (settings: Settings) => void;

  // Logs (per project)
  logs: Record<string, LogEntry[]>;
  appendLog: (project: string, entry: LogEntry) => void;
  clearLogs: (project: string) => void;

  // Toasts
  toasts: Toast[];
  addToast: (toast: Omit<Toast, 'id'>) => void;
  dismissToast: (id: string) => void;

  // UI state
  daemonConnected: boolean;
  setDaemonConnected: (connected: boolean) => void;
  searchQuery: string;
  setSearchQuery: (query: string) => void;
  projectViewMode: 'grid' | 'list';
  setProjectViewMode: (mode: 'grid' | 'list') => void;
  sidebarCollapsed: boolean;
  toggleSidebar: () => void;
}

export const useAppStore = create<AppState>((set) => ({
  // Projects
  projects: [],
  projectsLoaded: false,
  setProjects: (projects) => set({ projects, projectsLoaded: true }),
  updateProject: (name, updates) =>
    set((state) => ({
      projects: state.projects.map((p) =>
        p.name === name ? { ...p, ...updates } : p
      ),
    })),
  upsertProject: (project) =>
    set((state) => {
      const exists = state.projects.some((p) => p.name === project.name);

      if (exists) {
        return {
          projects: state.projects.map((p) =>
            p.name === project.name ? project : p
          ),
        };
      }

      return { projects: [...state.projects, project] };
    }),

  // Services
  services: [],
  setServices: (services) => set({ services }),
  updateService: (name, updates) =>
    set((state) => ({
      services: state.services.map((s) =>
        s.name === name ? { ...s, ...updates } : s
      ),
    })),

  // Health (system-level)
  health: null,
  setHealth: (health) => set({ health }),

  // Project Health
  projectHealth: {},
  setProjectHealth: (projectHealth) => set({ projectHealth }),
  updateProjectHealth: (name, status) =>
    set((state) => ({
      projectHealth: { ...state.projectHealth, [name]: status },
    })),

  // Dependency Graph
  dependencyGraph: {},
  setDependencyGraph: (dependencyGraph) => set({ dependencyGraph }),

  // Settings
  settings: null,
  setSettings: (settings) => set({ settings }),

  // Logs
  logs: {},
  appendLog: (project, entry) =>
    set((state) => {
      const existing = state.logs[project] || [];
      // Keep last 1000 lines per project
      const updated = [...existing, entry].slice(-1000);
      return { logs: { ...state.logs, [project]: updated } };
    }),
  clearLogs: (project) =>
    set((state) => {
      const { [project]: _, ...rest } = state.logs;
      return { logs: rest };
    }),

  // Toasts
  toasts: [],
  addToast: (toast) =>
    set((state) => ({
      toasts: [
        ...state.toasts,
        { ...toast, id: crypto.randomUUID() },
      ],
    })),
  dismissToast: (id) =>
    set((state) => ({
      toasts: state.toasts.filter((t) => t.id !== id),
    })),

  // UI state
  daemonConnected: false,
  setDaemonConnected: (connected) => set({ daemonConnected: connected }),
  searchQuery: '',
  setSearchQuery: (query) => set({ searchQuery: query }),
  projectViewMode: 'grid',
  setProjectViewMode: (mode) => set({ projectViewMode: mode }),
  sidebarCollapsed: false,
  toggleSidebar: () => set((s) => ({ sidebarCollapsed: !s.sidebarCollapsed })),
}));
