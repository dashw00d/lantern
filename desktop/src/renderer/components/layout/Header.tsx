import { useEffect, useRef } from 'react';
import { useLocation } from 'react-router-dom';
import { Search } from 'lucide-react';
import { useAppStore } from '../../stores/appStore';
import { Input } from '../ui/Input';

const pageTitles: Record<string, string> = {
  '/': 'Dashboard',
  '/projects': 'Projects',
  '/services': 'Services',
  '/settings': 'Settings',
};

export function Header() {
  const location = useLocation();
  const searchQuery = useAppStore((s) => s.searchQuery);
  const setSearchQuery = useAppStore((s) => s.setSearchQuery);
  const searchEnabled =
    location.pathname === '/projects' || location.pathname === '/';

  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault();
        if (searchEnabled) {
          inputRef.current?.focus();
        }
      }
      if (e.key === 'Escape' && document.activeElement === inputRef.current) {
        setSearchQuery('');
        inputRef.current?.blur();
      }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [searchEnabled, setSearchQuery]);

  const title =
    pageTitles[location.pathname] ||
    (location.pathname.startsWith('/projects/') ? 'Project Detail' : '');

  useEffect(() => {
    if (!searchEnabled && searchQuery !== '') {
      setSearchQuery('');
    }
  }, [searchEnabled, searchQuery, setSearchQuery]);

  return (
    <header className="flex h-14 items-center justify-between border-b border-border px-6">
      <h1 className="text-lg font-semibold">{title}</h1>

      {searchEnabled ? (
        <div className="relative">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            ref={inputRef}
            type="text"
            placeholder="Search projects... (Ctrl+K)"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-64 pl-9"
          />
        </div>
      ) : (
        <p className="text-xs text-muted-foreground">Project search is available on Dashboard and Projects.</p>
      )}
    </header>
  );
}
