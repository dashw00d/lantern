# Lantern Purpose-Fit Gap Analysis

Date: 2026-02-15

## Product intent (interpreted)
Lantern should be the source of truth for:
1. Routing local projects, APIs, and selected external sites to `.glow` domains
2. Declaring entries as tools/projects/websites and exposing an "available tools" API
3. Storing project docs and serving browsable docs at `lighthouse.glow/[project]/docs`
4. Supporting both runnable projects (with run commands) and docs-only/folder-only entries
5. Manual lifecycle operations: add, categorize, hide/unhide, remove per entry

## Executive summary
- Strong foundation exists for project registry, docs metadata, deploy/run commands, and health.
- Core gaps are at the "tool/web registry product" layer: no dedicated tools API, no lighthouse docs host path, no external-website proxy model, and limited UI lifecycle controls (manual add/hide/remove/categorize).
- Existing data model already has many needed fields (`kind`, `enabled`, `docs`, `routing`, `tags`) but they are not consistently surfaced in UI/APIs.

## Requirement-by-requirement verdict
Scale:
- `Green`: implemented and aligned
- `Yellow`: partial / usable but not product-complete
- `Red`: missing or materially misaligned

### 1) Connect project APIs or other websites to `.glow`
Verdict: `Yellow/Red`

What exists:
- `.glow` routing via per-project Caddy config for:
  - PHP/static from local folder
  - proxy to `127.0.0.1:<port>`
- Files:
  - `daemon/lib/lantern/system/caddy.ex`
  - `daemon/lib/lantern/projects/manager.ex`

Gap:
- No first-class external upstream model (for example, reverse-proxying `https://remote.site` to `foo.glow`).
- `base_url` is metadata/health-only today, not used by routing.

Impact:
- You can route local runtime/static projects, but not generic "website alias" entries.

### 2) Declare some entries as tools + expose "available tools" API
Verdict: `Yellow`

What exists:
- `kind` enum supports `service | project | capability`.
- MCP tooling supports listing/searching projects and filtering by kind/tag/status.
- Files:
  - `daemon/lib/lantern/projects/project.ex`
  - `daemon/lib/lantern/mcp/tools/list_projects.ex`
  - `daemon/lib/lantern/mcp/tools/search_projects.ex`

Gap:
- No HTTP `/api/tools` (or equivalent filtered registry) for non-MCP consumers.
- Existing REST surface is project-centric (`/api/projects`), not tool-centric.
- "available tools" is conceptually in place but not exposed as a dedicated contract.

Impact:
- AI via MCP can discover entries, but Loom/web clients expecting a clean tools API need adapters or custom filters.

### 3) Enter docs at project level and serve at `lighthouse.glow/[project]/docs`
Verdict: `Yellow/Red`

What exists:
- Per-project docs data model (`project.docs`) and raw doc serving API:
  - `GET /api/projects/:name/docs`
  - `GET /api/projects/:name/docs/*filename`
- Files:
  - `daemon/lib/lantern/projects/doc_server.ex`
  - `daemon/lib/lantern_web/controllers/doc_controller.ex`
  - `daemon/lib/lantern_web/router.ex`

Gap:
- No host/path-level web docs portal at `lighthouse.glow/[project]/docs`.
- Docs are API-served on daemon port, not exposed as a lighthouse `.glow` browsing experience.

Impact:
- Programmatic docs access is present, but human-friendly central docs URL model is missing.

### 4) Some entries need run commands
Verdict: `Green`

What exists:
- `run_cmd`, `run_cwd`, env support in model and manager.
- UI run-config editor and save flow.
- Files:
  - `daemon/lib/lantern/projects/project.ex`
  - `daemon/lib/lantern/projects/manager.ex`
  - `desktop/src/renderer/pages/ProjectDetail.tsx`

### 5) Store project as folder-only entry (docs-only possible)
Verdict: `Yellow`

What exists:
- Register API allows name/path with optional metadata/docs.
- Unknown type entries can be stored without runtime execution.
- Files:
  - `daemon/lib/lantern_web/controllers/project_controller.ex`
  - `daemon/lib/lantern/projects/manager.ex`

Gap:
- No first-class "docs-only" mode in UI/workflow.
- No lighthouse docs portal means folder-only doc entries are less discoverable.
- `DocServer.list/1` assumes each doc entry has map shape (`doc.path`), while API create path may accept docs without normalization.

Impact:
- Concept works in backend, but ergonomics/validation need hardening.

### 6) Categorize tools/projects/websites
Verdict: `Yellow`

What exists:
- `kind`, `tags`, `routing`, `description` fields.
- Files:
  - `daemon/lib/lantern/projects/project.ex`
  - `daemon/lib/lantern/config/lantern_yml.ex`

Gap:
- `kind` currently limited to `service | project | capability` (no explicit `website`/`tool` label unless mapped via tags/kind policy).
- UI does not provide category editing controls.

Impact:
- Data model can support categorization, but user-facing categorization is limited.

### 7) Add manually
Verdict: `Yellow`

What exists:
- Backend `POST /api/projects` registration exists.

Gap:
- No first-class desktop UI flow to add/register entries manually.

Impact:
- Requires API/CLI or external tooling, reducing convenience.

### 8) Hide / remove individually
Verdict: `Yellow`

What exists:
- Remove: `DELETE /api/projects/:name`.
- Hidden flag equivalent: `enabled` exists in model and updates.
- Health checker respects `enabled == true`.
- Files:
  - `daemon/lib/lantern/projects/project.ex`
  - `daemon/lib/lantern/health/checker.ex`
  - `daemon/lib/lantern_web/controllers/project_controller.ex`

Gap:
- UI lacks hide/unhide/remove controls.
- No consistent "enabled filtering contract" for list endpoints/UI.
- Activation/routing behavior does not globally enforce disabled semantics.

Impact:
- Remove is possible via API, but "hide" is not a coherent end-user feature yet.

## High-risk mismatches blocking your target workflow
1. No dedicated tools HTTP registry (`/api/tools`) while ecosystem docs/specs expect one.
2. No `lighthouse.glow/[project]/docs` host/path implementation.
3. No external-site aliasing model to map arbitrary websites into `.glow`.
4. UI missing manual add/categorize/hide/remove lifecycle actions.

## Suggested target model (minimal, concrete)
### A) Normalize entry taxonomy
Add/standardize:
- `kind`: `service | project | capability | website`
- `enabled`: hide/unhide semantic
- `visibility`: optional (`visible | hidden`) if you want separation from operational enablement

### B) Add explicit routing target
Current `type` is runtime/serve type; keep it.
Add one field for external aliases:
- `upstream_url` (nullable string)

Routing rule:
- if `upstream_url` present => Caddy `reverse_proxy` upstream URL
- else current local behavior (`php/static/proxy + port`)

### C) Add tools-facing HTTP APIs
Add:
- `GET /api/tools` (enabled entries with kind in `service|capability|website` by default; query filters)
- `GET /api/tools/:id`
- `GET /api/tools/:id/docs`

### D) Add lighthouse docs portal
Two routes on daemon web:
- `GET /lighthouse/:project/docs` (index page/json)
- `GET /lighthouse/:project/docs/*filename` (render/raw passthrough)

Then add Caddy site:
- `lighthouse.glow` -> reverse proxy to daemon route.

### E) Desktop UX lifecycle
Add to Projects page:
- `Add Entry` modal (name, path, kind, optional domain/run command/docs)
- `Hide/Unhide` toggle (`enabled`)
- `Remove` action with confirmation
- `Kind` selector and tags editor

## Phased implementation plan
1. Backend contracts first:
   - tools APIs
   - `upstream_url`
   - docs portal routes
   - validation normalization for docs entries and kind/type patching
2. Caddy integration:
   - external upstream routing
   - lighthouse host route
3. Desktop lifecycle UI:
   - add/hide/remove/categorize
4. Polish:
   - filter defaults (`show hidden`)
   - explicit docs-only entry template

## Acceptance criteria (for your stated needs)
1. I can register a docs-only folder and browse docs at `https://lighthouse.glow/<project>/docs`.
2. I can register an external site/API and access it via `<alias>.glow`.
3. I can classify entries as tool/project/website and fetch them from a dedicated "available tools" API.
4. I can manually add, hide, unhide, and remove entries from the desktop UI.
5. Hidden entries are omitted from default lists and routing surfaces unless explicitly requested.
