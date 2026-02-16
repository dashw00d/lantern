# Lantern Implementation Task Tracker

Date started: 2026-02-15
Owner: Codex

## Completed in prior passes
- [x] Fix detail-page cold-load state upsert regression
- [x] Preserve manually registered projects across scan
- [x] Remove unsafe atomization in project deserialization
- [x] Fix MCP docs resource URI/read handling
- [x] Normalize `type`/`kind` JSON strings before registration
- [x] Add Projects page category filters (`Tools/Sites/APIs/Projects`)
- [x] Add manual entry modal with local folder + remote URL modes
- [x] Add desktop folder picker bridge and IPC handler
- [x] Add tools HTTP endpoints (`/api/tools`, `/api/tools/:id`, `/api/tools/:id/docs`)
- [x] Add lighthouse docs routes and host wiring
- [x] Pass daemon + desktop test/build gates

## Additional gaps closed in this pass
- [x] Added `lantern*.glow` reverse-proxy host to daemon API (same Caddy generated config as lighthouse host)
- [x] Enforced hide semantics for running projects (disabling a running entry now deactivates it)
- [x] Edit-page parity for Add-flow fields (name/category/source/path or URL/domain/run command/docs/tags/docs-only)

## Remaining implementation items
1. [x] Tool API contract parity with integration/spec docs
Status: completed
Scope:
- Include routing triggers/risk/agents fields in tool payload contract
- Include health status field for tool list/detail
- Align response envelope/field naming expected by integration docs

2. [x] UI integration for available-tools surface
Status: completed
Scope:
- Add UI consumption of `/api/tools`
- Show tool descriptions and routing metadata where relevant

3. [x] Tags and docs-first entry UX
Status: completed
Scope:
- Add tags editor in add/edit flows
- Add explicit docs-only entry mode/template

4. [x] Project channel contract alignment
Status: completed
Scope:
- Emit `project_updated` and/or `projects_changed` from backend
- Or remove unused listeners and standardize on current events

5. [x] Service realtime wiring completion
Status: completed
Scope:
- Add PubSub producers for `services:lobby` `service_updated`
- Ensure frontend reflects live service state transitions

6. [x] Deploy logs/status UI
Status: completed
Scope:
- Expose `deployLogs` and `deployStatus` actions in project detail deploy tab

7. [x] Search behavior clarity
Status: completed
Scope:
- Route-scope global search, or clearly label as project-only search

8. [x] Dependencies endpoint parity (spec)
Status: completed
Scope:
- Add per-project dependencies/dependents endpoints or update spec/docs to match product decision

## Validation checklist (must run before done)
- [x] `cd daemon && mix test`
- [x] `cd desktop && npm run typecheck`
- [x] `cd desktop && npm run build`
