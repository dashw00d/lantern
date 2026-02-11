import { NavLink } from 'react-router-dom';
import {
  LayoutDashboard,
  FolderKanban,
  Server,
  Settings,
} from 'lucide-react';
import { useState } from 'react';
import { cn } from '../../lib/utils';
import { useAppStore } from '../../stores/appStore';
import appIcon from '../../../../resources/icon.png';

const navItems = [
  { to: '/', label: 'Dashboard', icon: LayoutDashboard },
  { to: '/projects', label: 'Projects', icon: FolderKanban },
  { to: '/services', label: 'Services', icon: Server },
  { to: '/settings', label: 'Settings', icon: Settings },
];

export function Sidebar() {
  const daemonConnected = useAppStore((s) => s.daemonConnected);
  const [showIconFallback, setShowIconFallback] = useState(false);

  return (
    <aside className="flex w-56 flex-col border-r border-border bg-card">
      <div className="flex h-14 items-center gap-2 border-b border-border px-4">
        {showIconFallback ? (
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary text-primary-foreground font-bold text-sm">
            L
          </div>
        ) : (
          <img
            src={appIcon}
            alt="Lantern icon"
            className="h-8 w-8 rounded-lg object-cover"
            onError={() => setShowIconFallback(true)}
          />
        )}
        <span className="font-semibold text-lg">Lantern</span>
      </div>

      <nav className="flex-1 space-y-1 p-3">
        {navItems.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.to === '/'}
            className={({ isActive }) =>
              cn(
                'flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors',
                isActive
                  ? 'bg-accent text-accent-foreground'
                  : 'text-muted-foreground hover:bg-accent/50 hover:text-foreground'
              )
            }
          >
            <item.icon className="h-4 w-4" />
            {item.label}
          </NavLink>
        ))}
      </nav>

      <div className="border-t border-border p-3">
        <div className="flex items-center gap-2 text-xs text-muted-foreground">
          <div
            className={cn(
              'h-2 w-2 rounded-full',
              daemonConnected ? 'bg-green-500' : 'bg-red-500'
            )}
          />
          {daemonConnected ? 'Daemon connected' : 'Daemon disconnected'}
        </div>
      </div>
    </aside>
  );
}
