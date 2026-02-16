import { useEffect, useCallback } from 'react';
import { useAppStore } from '../stores/appStore';
import { api } from '../api/client';
import { joinChannel } from '../api/socket';
import { getLanternBridge } from '../lib/electron';
import type { Project, ProjectKind } from '../types';

export function useProjects() {
  const projects = useAppStore((s) => s.projects);
  const setProjects = useAppStore((s) => s.setProjects);
  const updateProject = useAppStore((s) => s.updateProject);
  const upsertProject = useAppStore((s) => s.upsertProject);
  const addToast = useAppStore((s) => s.addToast);
  const searchQuery = useAppStore((s) => s.searchQuery);

  const fetchProjects = useCallback(async (includeHidden: boolean = false) => {
    try {
      const res = await api.listProjects({ includeHidden });
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
        upsertProject(res.data);
        addToast({ type: 'success', message: `Project "${name}" activated` });
        getLanternBridge()?.requestTrayRefresh();
      } catch (err) {
        updateProject(name, { status: 'error' });
        addToast({ type: 'error', message: `Failed to activate "${name}": ${err instanceof Error ? err.message : 'Unknown error'}` });
        throw err;
      }
    },
    [updateProject, upsertProject, addToast]
  );

  const deactivate = useCallback(
    async (name: string) => {
      updateProject(name, { status: 'stopping' });
      try {
        const res = await api.deactivateProject(name);
        upsertProject(res.data);
        addToast({ type: 'success', message: `Project "${name}" deactivated` });
        getLanternBridge()?.requestTrayRefresh();
      } catch (err) {
        updateProject(name, { status: 'error' });
        addToast({ type: 'error', message: `Failed to deactivate "${name}": ${err instanceof Error ? err.message : 'Unknown error'}` });
        throw err;
      }
    },
    [updateProject, upsertProject, addToast]
  );

  const restart = useCallback(
    async (name: string) => {
      updateProject(name, { status: 'starting' });
      try {
        const res = await api.restartProject(name);
        upsertProject(res.data);
        addToast({ type: 'success', message: `Project "${name}" restarted` });
        getLanternBridge()?.requestTrayRefresh();
      } catch (err) {
        updateProject(name, { status: 'error' });
        addToast({ type: 'error', message: `Failed to restart "${name}": ${err instanceof Error ? err.message : 'Unknown error'}` });
        throw err;
      }
    },
    [updateProject, upsertProject, addToast]
  );

  const scan = useCallback(async (includeHidden: boolean = false) => {
    try {
      const res = await api.scanProjects({ includeHidden });
      setProjects(res.data);
      addToast({ type: 'success', message: 'Project scan complete' });
      getLanternBridge()?.requestTrayRefresh();
    } catch (err) {
      addToast({ type: 'error', message: `Failed to scan projects: ${err instanceof Error ? err.message : 'Unknown error'}` });
    }
  }, [setProjects, addToast]);

  const create = useCallback(
    async (
      project: Partial<Project> & { name: string; path: string },
      includeHidden: boolean = false
    ) => {
      try {
        const res = await api.createProject(project);
        upsertProject(res.data);
        addToast({ type: 'success', message: `Project "${res.data.name}" added` });
        await fetchProjects(includeHidden);
        return res.data;
      } catch (err) {
        addToast({
          type: 'error',
          message: `Failed to add project: ${err instanceof Error ? err.message : 'Unknown error'}`,
        });
        throw err;
      }
    },
    [addToast, fetchProjects, upsertProject]
  );

  const setHidden = useCallback(
    async (name: string, hidden: boolean, includeHidden: boolean = false) => {
      try {
        const res = await api.patchProject(name, { enabled: !hidden });
        upsertProject(res.data);
        addToast({
          type: 'success',
          message: hidden ? `Project "${name}" hidden` : `Project "${name}" unhidden`,
        });
        await fetchProjects(includeHidden);
        return res.data;
      } catch (err) {
        addToast({
          type: 'error',
          message: `Failed to update visibility for "${name}": ${err instanceof Error ? err.message : 'Unknown error'}`,
        });
        throw err;
      }
    },
    [addToast, fetchProjects, upsertProject]
  );

  const setKind = useCallback(
    async (name: string, kind: ProjectKind) => {
      try {
        const res = await api.patchProject(name, { kind });
        upsertProject(res.data);
        addToast({ type: 'success', message: `Project "${name}" updated` });
        return res.data;
      } catch (err) {
        addToast({
          type: 'error',
          message: `Failed to update "${name}": ${err instanceof Error ? err.message : 'Unknown error'}`,
        });
        throw err;
      }
    },
    [addToast, upsertProject]
  );

  const remove = useCallback(
    async (name: string, includeHidden: boolean = false) => {
      try {
        await api.deleteProject(name);
        setProjects(useAppStore.getState().projects.filter((p) => p.name !== name));
        addToast({ type: 'success', message: `Project "${name}" removed` });
        await fetchProjects(includeHidden);
      } catch (err) {
        addToast({
          type: 'error',
          message: `Failed to remove "${name}": ${err instanceof Error ? err.message : 'Unknown error'}`,
        });
        throw err;
      }
    },
    [addToast, fetchProjects, setProjects]
  );

  const filtered = searchQuery
    ? projects.filter(
        (p) =>
          p.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
          (p.domain || '').toLowerCase().includes(searchQuery.toLowerCase())
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
    create,
    setHidden,
    setKind,
    remove,
  };
}

// Channel subscription for real-time project updates
export function useProjectChannel() {
  const updateProject = useAppStore((s) => s.updateProject);
  const setProjects = useAppStore((s) => s.setProjects);
  const upsertProject = useAppStore((s) => s.upsertProject);

  useEffect(() => {
    const channel = joinChannel('project:lobby');

    channel.on(
      'status_change',
      (payload: { project: string; status: Project['status'] }) => {
        updateProject(payload.project, { status: payload.status });
      }
    );

    channel.on('project_updated', (payload: { project: Project }) => {
      upsertProject(payload.project);
    });

    channel.on('projects_changed', (payload: { projects: Project[] }) => {
      setProjects(payload.projects);
    });

    return () => {
      // Channel cleanup handled by socket manager
    };
  }, [updateProject, setProjects, upsertProject]);
}
