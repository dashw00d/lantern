import { useEffect, useCallback } from 'react';
import { useAppStore } from '../stores/appStore';
import { api } from '../api/client';
import { joinChannel } from '../api/socket';
import { getLanternBridge } from '../lib/electron';
import type { Project } from '../types';

export function useProjects() {
  const projects = useAppStore((s) => s.projects);
  const setProjects = useAppStore((s) => s.setProjects);
  const updateProject = useAppStore((s) => s.updateProject);
  const addToast = useAppStore((s) => s.addToast);
  const searchQuery = useAppStore((s) => s.searchQuery);

  const fetchProjects = useCallback(async () => {
    try {
      const res = await api.listProjects();
      setProjects(res.data);
    } catch (err) {
      console.error('Failed to fetch projects:', err);
    }
  }, [setProjects]);

  useEffect(() => {
    fetchProjects();
  }, [fetchProjects]);

  const activate = useCallback(
    async (name: string) => {
      updateProject(name, { status: 'starting' });
      try {
        const res = await api.activateProject(name);
        updateProject(name, res.data);
        addToast({ type: 'success', message: `Project "${name}" activated` });
        getLanternBridge()?.requestTrayRefresh();
      } catch (err) {
        updateProject(name, { status: 'error' });
        addToast({ type: 'error', message: `Failed to activate "${name}": ${err instanceof Error ? err.message : 'Unknown error'}` });
        throw err;
      }
    },
    [updateProject, addToast]
  );

  const deactivate = useCallback(
    async (name: string) => {
      updateProject(name, { status: 'stopping' });
      try {
        const res = await api.deactivateProject(name);
        updateProject(name, res.data);
        addToast({ type: 'success', message: `Project "${name}" deactivated` });
        getLanternBridge()?.requestTrayRefresh();
      } catch (err) {
        updateProject(name, { status: 'error' });
        addToast({ type: 'error', message: `Failed to deactivate "${name}": ${err instanceof Error ? err.message : 'Unknown error'}` });
        throw err;
      }
    },
    [updateProject, addToast]
  );

  const restart = useCallback(
    async (name: string) => {
      updateProject(name, { status: 'starting' });
      try {
        const res = await api.restartProject(name);
        updateProject(name, res.data);
        addToast({ type: 'success', message: `Project "${name}" restarted` });
        getLanternBridge()?.requestTrayRefresh();
      } catch (err) {
        updateProject(name, { status: 'error' });
        addToast({ type: 'error', message: `Failed to restart "${name}": ${err instanceof Error ? err.message : 'Unknown error'}` });
        throw err;
      }
    },
    [updateProject, addToast]
  );

  const scan = useCallback(async () => {
    try {
      const res = await api.scanProjects();
      setProjects(res.data);
      addToast({ type: 'success', message: 'Project scan complete' });
      getLanternBridge()?.requestTrayRefresh();
    } catch (err) {
      addToast({ type: 'error', message: `Failed to scan projects: ${err instanceof Error ? err.message : 'Unknown error'}` });
    }
  }, [setProjects, addToast]);

  const filtered = searchQuery
    ? projects.filter(
        (p) =>
          p.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
          p.domain.toLowerCase().includes(searchQuery.toLowerCase())
      )
    : projects;

  return {
    projects: filtered,
    allProjects: projects,
    fetchProjects,
    activate,
    deactivate,
    restart,
    scan,
  };
}

// Channel subscription for real-time project updates
export function useProjectChannel() {
  const updateProject = useAppStore((s) => s.updateProject);
  const setProjects = useAppStore((s) => s.setProjects);

  useEffect(() => {
    const channel = joinChannel('project:lobby');

    channel.on('project_updated', (payload: { project: Project }) => {
      updateProject(payload.project.name, payload.project);
    });

    channel.on('projects_changed', (payload: { projects: Project[] }) => {
      setProjects(payload.projects);
    });

    return () => {
      // Channel cleanup handled by socket manager
    };
  }, [updateProject, setProjects]);
}
