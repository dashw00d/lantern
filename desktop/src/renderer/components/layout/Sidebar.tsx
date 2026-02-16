import { NavLink } from 'react-router-dom';
import {
  LayoutDashboard,
  FolderKanban,
  Server,
  Settings,
  ChevronLeft,
  ChevronRight,
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
  const sidebarCollapsed = useAppStore((s) => s.sidebarCollapsed);
  const toggleSidebar = useAppStore((s) => s.toggleSidebar);
  const [showIconFallback, setShowIconFallback] = useState(false);

  return (
    <aside
      className={cn(
        'flex flex-col border-r border-border bg-card transition-all duration-200',
        sidebarCollapsed ? 'w-14' : 'w-56'
      )}
    >
      <div className={cn(
        'flex h-14 items-center border-b border-border',
        sidebarCollapsed ? 'justify-center px-0' : 'gap-2 px-4'
      )}>
        {showIconFallback ? (
          <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-primary text-primary-foreground font-bold text-sm">
            L
          </div>
        ) : (
          <img
            src={appIcon}
            alt="Lantern icon"
            className="h-8 w-8 shrink-0 rounded-lg object-cover"
            onError={() => setShowIconFallback(true)}
          />
        )}
        {!sidebarCollapsed && (
          <span className="font-semibold text-lg">Lantern</span>
        )}
      </div>

      <nav className={cn('flex-1 space-y-1', sidebarCollapsed ? 'p-1.5' : 'p-3')}>
        {navItems.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.to === '/'}
            title={sidebarCollapsed ? item.label : undefined}
            className={({ isActive }) =>
              cn(
                'flex items-center rounded-md text-sm font-medium transition-colors',
                sidebarCollapsed
                  ? 'justify-center px-0 py-2'
                  : 'gap-3 px-3 py-2',
                isActive
                  ? 'bg-accent text-accent-foreground'
                  : 'text-muted-foreground hover:bg-accent/50 hover:text-foreground'
              )
            }
          >
            <item.icon className="h-4 w-4 shrink-0" />
            {!sidebarCollapsed && item.label}
          </NavLink>
        ))}
      </nav>

      <div className="border-t border-border p-3">
        <div className={cn(
          'flex items-center text-xs text-muted-foreground',
          sidebarCollapsed ? 'justify-center' : 'gap-2'
        )}>
          <div
            role="status"
            aria-label={daemonConnected ? 'Daemon connected' : 'Daemon disconnected'}
            className={cn(
              'h-2 w-2 shrink-0 rounded-full',
              daemonConnected ? 'bg-green-500' : 'bg-red-500'
            )}
            title={sidebarCollapsed ? (daemonConnected ? 'Daemon connected' : 'Daemon disconnected') : undefined}
          />
          {!sidebarCollapsed && (daemonConnected ? 'Daemon connected' : 'Daemon disconnected')}
        </div>
      </div>

      <div className="border-t border-border">
        <button
          onClick={toggleSidebar}
          className="flex w-full items-center justify-center py-2 text-muted-foreground hover:bg-accent/50 hover:text-foreground transition-colors"
          title={sidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar'}
          aria-label={sidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar'}
        >
          {sidebarCollapsed ? (
            <ChevronRight className="h-4 w-4" />
          ) : (
            <ChevronLeft className="h-4 w-4" />
          )}
        </button>
      </div>
    </aside>
  );
}
