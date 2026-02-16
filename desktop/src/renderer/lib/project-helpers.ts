import type { ProjectKind } from '../types';

export type EntryCategory = 'tool' | 'site' | 'api' | 'project';
export type EntryMode = 'local' | 'remote';

export function categoryFromKind(kind: ProjectKind): EntryCategory {
  if (kind === 'tool') return 'tool';
  if (kind === 'website') return 'site';
  if (kind === 'service' || kind === 'capability') return 'api';
  return 'project';
}

export function kindFromCategory(category: EntryCategory): ProjectKind {
  if (category === 'tool') return 'tool';
  if (category === 'site') return 'website';
  if (category === 'api') return 'service';
  return 'project';
}
