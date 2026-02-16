# Lantern Desktop UI — Complete Element Audit

Every interactive element (button, input, link, select, checkbox, toggle) across all pages.

---

## 1. Dashboard

**File:** `desktop/src/renderer/pages/Dashboard.tsx`

| Location | Type | What it does | Lines |
|---|---|---|---|
| Project Health header | Button | Refresh — re-fetches health data | 98-104 |
| Project Health grid | Link (×N) | Clickable card per project → navigates to `/projects/{name}` | 107-131 |
| Active Routes — empty state | Link | "Activate a project" → navigates to `/projects` | 144-149 |
| Active Routes — project row | Link | Project name → navigates to `/projects/{name}` | 160-165 |
| Active Routes — project row | Button | Copy URL — copies `https://{domain}` to clipboard | 171-177 |
| Active Routes — project row | Link (external) | Open in browser — opens project URL in new tab | 178-186 |
| Issues section | Link (×N) | Clickable issue row → navigates to `/projects/{name}` | 203-211 |

**Auto-refresh:** Health data polls every 30s (lines 34-38).

---

## 2. Projects Page

**File:** `desktop/src/renderer/pages/Projects.tsx`

### Filter Bar (top)

| Location | Type | What it does | Lines |
|---|---|---|---|
| Filter bar left | Select | Filter by status (All/Running/Stopped/Error/Needs Config) | 309-319 |
| Filter bar left | Select | Filter by type (All/PHP/Proxy/Static/Unknown) | 321-331 |
| Filter bar left | Checkbox | Show hidden projects toggle | 334-339 |
| Category strip | Button (×5) | Category filter: All / Tools / Sites / APIs / Projects | 389-402 |

### Toolbar (top right)

| Location | Type | What it does | Lines |
|---|---|---|---|
| Toolbar | Button | **Add** — opens Create Project modal | 344-350 |
| Toolbar | Button | **Scan** — triggers project scan (spinner while scanning) | 352-359 |
| Toolbar | Button | Grid view toggle | 362-372 |
| Toolbar | Button | List view toggle | 373-383 |

### Grid View — per ProjectCard

**File:** `desktop/src/renderer/components/projects/ProjectCard.tsx`

| Location | Type | What it does | Lines (ProjectCard) |
|---|---|---|---|
| Card header | Link | Project name → navigates to `/projects/{name}` | 34-44 |
| Card actions (running) | Button | Stop — deactivates project | 66-73 |
| Card actions (running) | Button | Restart — restarts project | 74-81 |
| Card actions (stopped) | Button | Start — activates project | 84-91 |
| Card actions (running) | Button | Copy URL — copies domain to clipboard | 97-103 |
| Card actions (running) | Link (external) | Open in browser | 104-112 |

**File:** `desktop/src/renderer/pages/Projects.tsx` (grid card footer)

| Location | Type | What it does | Lines |
|---|---|---|---|
| Card bottom | Select | Change category/kind (Project/API-Service/Tool/Site/Capability) | 443-453 |
| Card bottom | Button | Toggle hidden/visible | 454-464 |
| Card bottom | Button | Delete/Remove project (with confirm) | 465-471 |

### List View — per row

| Location | Type | What it does | Lines |
|---|---|---|---|
| Name column | Link | Project name → navigates to `/projects/{name}` | 502-507 |
| Category column | Select | Change category/kind | 526-536 |
| Actions column (running) | Button | Stop | 544-551 |
| Actions column (stopped) | Button | Start | 553-560 |
| Actions column | Button | Toggle hidden/visible | 563-573 |
| Actions column | Button | Delete/Remove (with confirm) | 575-581 |

---

## 3. Add Project Modal (inside Projects page)

**File:** `desktop/src/renderer/pages/Projects.tsx`

| Location | Type | What it does | Lines |
|---|---|---|---|
| Modal header | Button | Close (X) — dismisses modal | 602-607 |
| Form | Input (text) | **Name** — project name (required) | 613-617 |
| Form | Select | **Category** — Tool / Site / API / Project | 622-633 |
| Source section | Button (toggle) | **Local folder** — selects local source mode | 639-654 |
| Source section | Button (toggle) | **Remote URL** — selects remote source mode | 655-671 |
| Form (local mode) | Checkbox | **Docs-only entry** — no run command needed | 679-687 |
| Form (local mode) | Input (text) | **Folder path** | 695-698 |
| Form (local mode) | Button | **Browse** — opens OS folder picker | 700-706 |
| Form (remote mode) | Input (text) | **Remote URL** | 712-717 |
| Form (all modes) | Input (text) | **Domain** (.glow alias, optional) | 723-728 |
| Form (all modes) | Textarea | **Tags** (comma or newline separated) | 733-738 |
| Form (local, not docs-only) | Input (text) | **Run command** (optional) | 744-749 |
| Form (all modes) | Textarea | **Docs** (one relative path per line) | 755-760 |
| Footer | Button | **Cancel** — closes without saving | 765-769 |
| Footer | Button | **Add Entry** — submits form (disabled if name empty) | 771-777 |

**Validation:** toast errors for empty name, empty path (local), empty URL (remote) — `handleCreate` lines 231-288.

---

## 4. Project Detail Page

**File:** `desktop/src/renderer/pages/ProjectDetail.tsx`

### Header (always visible)

| Location | Type | What it does | Lines |
|---|---|---|---|
| Top left | Link | Back arrow → navigates to `/projects` | 204-209 |
| Header | Badge | TypeBadge (display only — PHP/Proxy/Static/Unknown) | 213 |
| Header | Badge | StatusBadge (display only — Running/Stopped/Error) | 214 |
| Header | Badge | Kind badge (display only — tool/website/service/capability) | 215-219 |
| Header right (running) | Button | **Stop** — deactivates project | 237-244 |
| Header right (running) | Button | **Restart** — restarts project | 245-252 |
| Header right (stopped) | Button | **Start** — activates project | 255-262 |
| Header right (running) | Link (external) | **Open** — opens domain in new tab | 264-274 |

### Tab Bar

| Location | Type | What it does | Lines |
|---|---|---|---|
| Tab strip | Button (×11) | Tab selectors: Overview, Entry, Run, Routing, Docs, Endpoints, Health, Dependencies, Deploy, Mail, Logs | 280-293 |

### Overview Tab

| Location | Type | What it does | Lines |
|---|---|---|---|
| Domain row | Button | Copy domain URL to clipboard | 338-344 |

### Entry Tab

| Location | Type | What it does | Lines |
|---|---|---|---|
| Form | Input (text) | Name | 607-611 |
| Form | Select | Category (Tool/Site/API/Project) | 616-626 |
| Source section | Button (toggle) | Local folder mode | 631-641 |
| Source section | Button (toggle) | Remote URL mode | 642-655 |
| Form (local) | Checkbox | Docs-only entry | 663-669 |
| Form (local) | Input (text) | Folder path | 677-681 |
| Form (local) | Button | Browse — OS folder picker | 682-687 |
| Form (remote) | Input (text) | Remote URL | 693-698 |
| Form | Input (text) | Domain (.glow alias) | 704-709 |
| Form (local, not docs-only) | Textarea | Run command | 715-721 |
| Form | Textarea | Docs paths | 726-731 |
| Form | Textarea | Tags | 737-741 |
| Footer | Button | **Save** | 746-752 |

### Run Tab

| Location | Type | What it does | Lines |
|---|---|---|---|
| Form | Textarea | Run command | 816-821 |
| Form | Input (text) | Working directory | 827-832 |
| Footer | Button | **Reset** — reverts changes | 855-864 |
| Footer | Button | **Save** — saves run config | 865-871 |

### Routing Tab

| Location | Type | What it does | Lines |
|---|---|---|---|
| Form | Input (text) | Domain (.glow alias) | 934-939 |
| Form | Textarea | Tags | 951-956 |
| Footer | Button | **Reset** — reverts changes | 961-970 |
| Footer | Button | **Save** — saves routing metadata | 971-977 |

### Docs Tab

| Location | Type | What it does | Lines |
|---|---|---|---|
| Editor section | Textarea | Docs paths (one per line) | 1054-1059 |
| Editor section | Button | **Save Docs** | 1061-1067 |
| Document list | Button (×N) | Doc file selector — loads and displays content | 1078-1092 |

### Endpoints Tab

Display only — no interactive elements (lines 1150-1167).

### Health Tab

| Location | Type | What it does | Lines |
|---|---|---|---|
| Header | Button | **Check Now** — triggers immediate health check | 1216-1223 |

### Dependencies Tab

| Location | Type | What it does | Lines |
|---|---|---|---|
| Depends On list | Link (×N) | Navigate to dependency project | 1330-1336 |
| Depended By list | Link (×N) | Navigate to dependent project | 1350-1356 |

### Deploy Tab

| Location | Type | What it does | Lines |
|---|---|---|---|
| Actions | Button | **Start** deploy (if deploy.start configured) | 1432-1439 |
| Actions | Button | **Stop** deploy (if deploy.stop configured) | 1442-1449 |
| Actions | Button | **Restart** deploy (if deploy.restart configured) | 1452-1459 |
| Actions | Button | **Logs** — fetch deploy logs (if deploy.logs configured) | 1462-1469 |
| Actions | Button | **Status** — fetch deploy status (if deploy.status configured) | 1472-1480 |

### Mail Tab

| Location | Type | What it does | Lines |
|---|---|---|---|
| Mailpit section (if enabled) | Link (external) | **Open Mailpit** — opens `http://127.0.0.1:8025` | 1524-1532 |

### Logs Tab

**File:** `desktop/src/renderer/components/common/LogViewer.tsx`

| Location | Type | What it does | Lines (LogViewer) |
|---|---|---|---|
| Log viewer header | Button | **Clear** — clears all log entries | 35-40 |

---

## 5. Services Page

**File:** `desktop/src/renderer/pages/Services.tsx`
**File:** `desktop/src/renderer/components/services/ServiceCard.tsx`

| Location | Type | What it does | Lines (ServiceCard) |
|---|---|---|---|
| Service card | Button | **Start/Stop** toggle — starts or stops service | 47-58 |
| Service card (running) | Link (external) | **Open UI** — opens `service.ui_url` in new tab | 60-70 |

**Real-time updates:** WebSocket listener on `services:lobby` channel for `service_updated` events.

---

## 6. Settings Page

**File:** `desktop/src/renderer/pages/Settings.tsx`

| Location | Type | What it does | Lines |
|---|---|---|---|
| Workspace Roots | Input (text) | New workspace root path (Enter to add) | 89-96 |
| Workspace Roots | Button | **Add** — adds entered root path | 97-103 |
| Workspace Roots (each) | Button | **X** — removes that root from list | 80-85 |
| Domain Settings | Input (text) | **TLD** — top-level domain | 114-119 |
| PHP Configuration | Input (text) | **PHP-FPM Socket Path** | 131-136 |
| Caddy Integration | Select | **Mode** — "Config Files" or "Admin API" | 145-152 |
| Bottom right | Button | **Save Settings** — persists all changes (spinner while saving) | 166-177 |

---

## 7. Global Layout Elements

### Sidebar — `desktop/src/renderer/components/layout/Sidebar.tsx`

Navigation links (always visible): Dashboard, Projects, Services, Settings.

### Header — `desktop/src/renderer/components/layout/Header.tsx`

| Location | Type | What it does | Lines |
|---|---|---|---|
| Header right | Input (text) | Search projects (Ctrl+K) — filters on Dashboard & Projects pages | 37-43 |

### HealthStrip — `desktop/src/renderer/components/common/HealthStrip.tsx`

Status indicators for DNS, Caddy, TLS, Daemon (display only, non-interactive).

---

## Summary Counts

| Page | Buttons | Inputs | Links | Selects | Checkboxes | Textareas | Total |
|---|---|---|---|---|---|---|---|
| Dashboard | 2 | 0 | 5+ | 0 | 0 | 0 | ~7+ |
| Projects (filters/toolbar) | 7 | 0 | 0 | 2 | 1 | 0 | 10 |
| Projects (grid card ×N) | 6 | 0 | 2 | 1 | 0 | 0 | 9/card |
| Projects (list row ×N) | 3 | 0 | 1 | 1 | 0 | 0 | 5/row |
| Add Project Modal | 4 | 5 | 0 | 1 | 1 | 2 | 13 |
| Project Detail (header) | 3 | 0 | 2 | 0 | 0 | 0 | 5 |
| Project Detail (tabs) | 11 | 0 | 0 | 0 | 0 | 0 | 11 |
| Project Detail (all tabs) | 12 | 7 | 2+ | 1 | 1 | 6 | ~29 |
| Services (per card) | 1 | 0 | 1 | 0 | 0 | 0 | 2/card |
| Settings | 3 | 3 | 0 | 1 | 0 | 0 | 7 |
| Header (global) | 0 | 1 | 0 | 0 | 0 | 0 | 1 |
