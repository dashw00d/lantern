# UI to Backend Connectivity Audit

Date: 2026-02-15
Scope: Desktop renderer UI (`desktop/src/renderer/*`) to daemon HTTP + Phoenix Channels (`daemon/lib/lantern_web/*`)

## Rating scale
- `10` = very convenient (fast, clear, reliable, low-friction)
- `7-9` = good with minor gaps
- `4-6` = usable but friction or mismatch is visible
- `1-3` = major convenience problem / broken expectation

## Shell and global controls
| UI item | Frontend wiring | Backend wiring | Convenience | Notes (redundancy / misconnection / UX) |
|---|---|---|---:|---|
| Sidebar nav (`Dashboard`, `Projects`, `Services`, `Settings`) | `desktop/src/renderer/components/layout/Sidebar.tsx` | None (client-side routes) | 8 | Clean and predictable. |
| Daemon connection indicator | Zustand `daemonConnected`; set by `useHealth` + Electron bridge (`desktop/src/renderer/hooks/useHealth.ts`, `desktop/src/renderer/hooks/useElectronBridge.ts`) | `GET /api/system/health` plus desktop bridge daemon-status callback | 6 | Redundant signal sources can disagree momentarily. |
| Global search box | `desktop/src/renderer/components/layout/Header.tsx` sets global `searchQuery` | None (local only) | 4 | Search appears on all pages but only affects project filtering logic; feels inert on `Services`/`Settings`. |
| Global toasts | Zustand store | No direct backend | 8 | Good feedback pattern; consistent. |

## Dashboard page
| UI item | Frontend wiring | Backend wiring | Convenience | Notes |
|---|---|---|---:|---|
| Health strip | `useHealth()` + `HealthStrip` (`desktop/src/renderer/pages/Dashboard.tsx`) | `GET /api/system/health`; channel `system:health` (`health_update`) | 7 | Works, but duplicated with both polling and channel stream. |
| Project stats cards | Derived from `useProjects().allProjects` | `GET /api/projects` | 7 | Simple and clear; tied to project list freshness. |
| Project health overview + refresh | `api.getProjectHealthAll()` | `GET /api/health` | 7 | Useful summary; background refresh every 30s is good. |
| Active routes list + quick open/copy | Derived from running projects | `GET /api/projects` | 8 | Fast path to active apps; no backend issues. |
| Issues panel | Derived from project statuses | `GET /api/projects` | 7 | Good surfacing; no direct action besides deep-link. |

## Projects page
| UI item | Frontend wiring | Backend wiring | Convenience | Notes |
|---|---|---|---:|---|
| Load project list | `useProjects.fetchProjects()` (`desktop/src/renderer/hooks/useProjects.ts`) | `GET /api/projects` | 8 | Reliable baseline. |
| Scan button | `useProjects.scan()` | `POST /api/projects/scan` | 7 | Works, but no diff view (new/removed/changed) and no detailed progress. |
| Start/Stop/Restart actions (cards + list row) | `activate/deactivate/restart` in `useProjects` and card/list controls | `POST /api/projects/:name/activate|deactivate|restart` | 8 | Good immediate feedback and optimistic state updates. |
| Grid/list toggles + filters | Local UI state | None | 8 | Fast local interaction. |
| Real-time project updates | `useProjectChannel` listens for `status_change`, `project_updated`, `projects_changed` | Channel `project:lobby` only pushes `status_change` (`daemon/lib/lantern_web/channels/project_channel.ex`) | 5 | Mismatch: frontend subscribes to events backend never emits (`project_updated`, `projects_changed`). |

## Project detail page
| UI item | Frontend wiring | Backend wiring | Convenience | Notes |
|---|---|---|---:|---|
| Deep-link load `/projects/:name` | `api.getProject(name)` with store upsert (`desktop/src/renderer/pages/ProjectDetail.tsx`) | `GET /api/projects/:name` | 8 | Cold-load issue was fixed; now robust. |
| Header Start/Stop/Restart | `api.activateProject/deactivateProject/restartProject` | `POST /api/projects/:name/activate|deactivate|restart` | 8 | Good parity with list page. |
| Overview tab | Pure render from `project` + clipboard/open links | Data from `GET /api/projects/:name` | 7 | Useful metadata view; read-only by design. |
| Run tab (save run command/cwd) | `api.updateProject()` | `PUT /api/projects/:name` | 8 | Good inline edit flow; clear save/reset affordance. |
| Routing tab (save domain) | `api.updateProject()` | `PUT /api/projects/:name` | 7 | Works; no domain validation hints in UI. |
| Docs tab | `api.listDocs()` + `api.getDoc()` | `GET /api/projects/:name/docs`, `GET /api/projects/:name/docs/*filename` | 6 | Works; filename path is not URL-encoded in client method and error states are minimal. |
| Endpoints tab | Renders `project.endpoints` only | Included in `GET /api/projects/:name` response | 5 | No refresh API call despite existing `getProjectEndpoints()` client method. Potential staleness. |
| Health tab | `api.getProjectHealth()` + `api.checkProjectHealth()` | `GET /api/projects/:name/health`, `POST /api/projects/:name/health/check` | 8 | Good drill-down and manual recheck. |
| Dependencies tab | `api.getDependencies()` and local project extraction | `GET /api/dependencies` | 6 | Simple but fetches global graph each view; no refresh affordance. |
| Deploy tab | `api.deployStart/Stop/Restart` | `POST /api/projects/:name/deploy/start|stop|restart` | 7 | Core commands exposed, but `deploy logs/status` APIs exist and are not surfaced. |
| Mail tab | Derived from `project.features.mailpit` | Included in project payload | 6 | Useful quick info; mostly static text and hardcoded Mailpit URL. |
| Logs tab | `useLogs(project:name)` Phoenix channel | Channel `project:<name>` `log_line` events | 8 | Solid live log stream UX. |

## Services page
| UI item | Frontend wiring | Backend wiring | Convenience | Notes |
|---|---|---|---:|---|
| Load services | `useServices.fetchServices()` | `GET /api/services` | 7 | Baseline works. |
| Start/Stop service | `api.startService/stopService` | `POST /api/services/:name/start|stop` | 7 | Straightforward and responsive. |
| Open service UI link | `service.ui_url` in `ServiceCard` | Backend returns `health_check_url` (not `ui_url`) in `ServiceController.index/2` | 3 | Field-name mismatch means UI link is usually missing. |
| Service credentials panel | `service.credentials` in `ServiceCard` | Not returned by `ServiceController` | 3 | UI slot exists but backend does not populate it. |
| Real-time service updates | `useServiceChannel` listens for `service_updated` | Channel exists, but no observed PubSub producers for `{:service_change, ...}` | 2 | Effectively disconnected realtime path. |

## Settings page
| UI item | Frontend wiring | Backend wiring | Convenience | Notes |
|---|---|---|---:|---|
| Load settings | `useSettings.fetchSettings()` | `GET /api/system/settings` | 8 | Reliable. |
| Save settings (roots, TLD, PHP socket, Caddy mode) | `useSettings.update()` | `PUT /api/system/settings` | 8 | Good single-save model with success/error toasts. |
| Workspace roots editing flow | Local add/remove then save | Persists through settings API | 7 | Works, but no guided follow-up action (for example: prompt to run project scan). |

## Redundancy findings
1. Health state is updated by both polling and channels:
   - Poll: `useHealth` every 15s (`desktop/src/renderer/hooks/useHealth.ts`)
   - Channel: `system:health` pushes every 30s (`desktop/src/renderer/hooks/useHealth.ts`, `daemon/lib/lantern_web/channels/health_channel.ex`)
2. Project list is fetched on each page mount via `useProjects`, while `project:lobby` join also returns initial projects payload that is not consumed.
3. Unused API surface in desktop client (implemented but not used in current UI):
   - `patchProject`, `deleteProject`, `getProjectEndpoints`, `deployLogs`, `deployStatus`, `getPorts`, `getServiceStatus`, `initSystem`, template/profile methods (`desktop/src/renderer/api/client.ts`).
4. Unused backend UI path:
   - SSE logs endpoint `GET /api/projects/:name/logs` exists but desktop logs use WebSocket channel instead.

## Misconnection findings
1. Service UI URL mismatch:
   - Frontend expects `service.ui_url` (`desktop/src/renderer/components/services/ServiceCard.tsx`)
   - Backend provides `health_check_url` (`daemon/lib/lantern_web/controllers/service_controller.ex`)
2. Frontend listens to project channel events that backend does not emit:
   - Listeners: `project_updated`, `projects_changed` (`desktop/src/renderer/hooks/useProjects.ts`)
   - Backend channel currently handles/pushes only `status_change` + `log_line` (`daemon/lib/lantern_web/channels/project_channel.ex`)
3. Service channel wiring appears incomplete:
   - Frontend subscribes to `services:lobby` and expects `service_updated`
   - No corresponding broadcasts found for `{:service_change, name, status}` producers.

## UX pain points
1. Global search is visually global but functionally project-focused, which is confusing on non-project pages.
2. Services page promises richer cards (`Open UI`, credentials), but backend payload lacks matching fields.
3. Endpoints and dependencies views are read-only snapshots with limited refresh controls.
4. Project creation/registration APIs exist but there is no first-class UI path to add/remove projects manually.
5. Deploy tab omits logs/status actions even though backend supports them.

## Priority recommendations
1. Fix service payload contract (`ui_url`, optional `credentials`) and/or update frontend to consume backend field names.
2. Complete or remove broken realtime contracts:
   - Emit `project_updated` / `projects_changed` or stop subscribing to them.
   - Add service PubSub broadcasts or remove `useServiceChannel`.
3. Consolidate health transport strategy (channel-first with poll fallback, or poll-only).
4. Add explicit UI for registration lifecycle (`createProject`, `deleteProject`) and deploy logs/status.
5. Scope global search by route (or label it as project search only).
