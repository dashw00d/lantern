import type { Project } from '../../types';

export interface TabProps {
  project: Project;
}

export interface EditableTabProps extends TabProps {
  onProjectUpdated: (project: Project) => void;
}
