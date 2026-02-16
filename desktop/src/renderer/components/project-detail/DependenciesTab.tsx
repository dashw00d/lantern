import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { GitBranch } from 'lucide-react';
import { api } from '../../api/client';
import { Card, CardContent } from '../ui/Card';
import type { TabProps } from './types';

export function DependenciesTab({ project }: TabProps) {
  const [deps, setDeps] = useState<{ depends_on: string[]; depended_by: string[] } | null>(null);

  useEffect(() => {
    Promise.all([
      api.getProjectDependencies(project.name),
      api.getProjectDependents(project.name),
    ])
      .then(([depsRes, dependentsRes]) => {
        setDeps({
          depends_on: depsRes.data.depends_on || [],
          depended_by: dependentsRes.data.depended_by || [],
        });
      })
      .catch((err) => console.warn('Failed to fetch project dependencies:', err));
  }, [project.name]);

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-2 gap-4">
        <Card>
          <CardContent>
            <h3 className="text-sm font-semibold mb-3 flex items-center gap-2">
              <GitBranch className="h-4 w-4" />
              Depends On
            </h3>
            {(deps?.depends_on?.length ?? 0) === 0 ? (
              <p className="text-sm text-muted-foreground">No dependencies</p>
            ) : (
              <div className="space-y-1">
                {deps!.depends_on.map((dep) => (
                  <Link
                    key={dep}
                    to={`/projects/${encodeURIComponent(dep)}`}
                    className="block rounded-md px-3 py-2 text-sm hover:bg-accent hover:text-primary"
                  >
                    {dep}
                  </Link>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
        <Card>
          <CardContent>
            <h3 className="text-sm font-semibold mb-3 flex items-center gap-2">
              <GitBranch className="h-4 w-4 rotate-180" />
              Depended By
            </h3>
            {(deps?.depended_by?.length ?? 0) === 0 ? (
              <p className="text-sm text-muted-foreground">Nothing depends on this project</p>
            ) : (
              <div className="space-y-1">
                {deps!.depended_by.map((dep) => (
                  <Link
                    key={dep}
                    to={`/projects/${encodeURIComponent(dep)}`}
                    className="block rounded-md px-3 py-2 text-sm hover:bg-accent hover:text-primary"
                  >
                    {dep}
                  </Link>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
