# Runtime Testing And Regression Report

Date: 2026-02-16
Scope: Source-mode daemon testing via `dev-up.sh` against live API on `127.0.0.1:4777`

## Verification Rerun (2026-02-16, post-fix)

Re-ran runtime smoke and regression-focused checks against source daemon on `127.0.0.1:4777`.

### Executed

1. Runtime smoke:
   - `GET /api/system/health`
   - `GET /`
   - `GET /api/projects?include_hidden=true`
   - `GET /api/tools?include_hidden=true`
2. Manual in-root durability probe:
   - `POST /api/projects` (manual in-root registration)
   - `POST /api/projects/scan?include_hidden=true`
   - Verify project remains in `/api/projects` and `/api/tools`
3. Focused regression tests:
   - `mix test test/lantern_web/controllers/project_controller_test.exs test/lantern_web/controllers/tool_controller_test.exs`

### Result

- Runtime smoke: pass
- Manual in-root durability: pass (`before=true`, `after=true`, `tools=true`)
- Focused controller tests: `22 tests, 0 failures`

Conclusion: the previously reported scan-durability regression no longer reproduces in this rerun.

## 1) How The Runtime Testing Was Performed

### Environment Loop

1. Start clean:

```bash
bash dev-down.sh
```

2. Start source daemon:

```bash
bash dev-up.sh
```

3. Run API sweeps from a second shell with `curl` + `jq`.
4. Stop runtime:

```bash
bash dev-down.sh
```

### What Was Tested

The runtime sweep exercised:

1. System health and root discovery.
2. Project create/read/update/delete.
3. Lifecycle actions: `activate`, `deactivate`, `restart`.
4. Enum normalization on create (`"type": "proxy"`, `"kind": "service"`).
5. Docs API index endpoint: `/api/projects/:name/docs`.
6. Docs API file endpoint: `/api/projects/:name/docs/:file`.
7. Lighthouse docs index endpoint: `/:project/docs`.
8. Lighthouse docs file endpoint: `/:project/docs/:file`.
9. Tools list with kind filter: `/api/tools?kind=service&include_hidden=true`.
10. Tool detail with kind filter: `/api/tools/:id?kind=service&include_hidden=true`.
11. Tool docs with kind filter: `/api/tools/:id/docs?kind=service&include_hidden=true`.
12. Hidden-project behavior (`enabled=false` should reject activation).
13. Scan endpoint under include-hidden mode: `POST /api/projects/scan?include_hidden=true`.
14. Manual entry persistence across scan.

### Runtime Sweep Result

Main deterministic sweep result:

- `48 passed, 0 failed`

This was against an isolated generated test project (`lantern-devtest-*`) and validated end-to-end behavior for create/edit/docs/tools/scan flows.

## 2) Regressions Found

### Regression A: Manual in-root registrations are dropped by scan

Severity: High (user-visible data loss, empties tools list)

### Reproduction

1. Register a manual service/tool whose `path` is inside workspace roots, e.g. `/home/ryan/sites/Lantern`.
2. Confirm it appears in `/api/projects?include_hidden=true`.
3. Run:

```bash
curl -X POST "http://127.0.0.1:4777/api/projects/scan?include_hidden=true"
```

4. Re-check `/api/projects?include_hidden=true` and `/api/tools?include_hidden=true`.

### Observed

- The manual project disappears after scan.
- `/api/tools` can become empty as a side effect.

### Why this likely happens

In `daemon/lib/lantern/projects/manager.ex`, `preserve_registered_projects/3` currently skips preserving projects whose path is under workspace roots (`project_in_workspace_roots?/2` check).  
That condition removes manual registrations in normal dev folders after scan.

Relevant code location:

- `daemon/lib/lantern/projects/manager.ex:651`

### Regression B: None additional in current source-mode sweep

No other deterministic runtime regressions were reproduced in the final isolated sweep.

## 3) How To Find More Regressions

Use invariant-based sweeps, not one-off endpoint checks.

### A) Scan durability invariant matrix

For each combination below, enforce: `create -> scan -> still exists`:

1. `kind`: `service`, `tool`, `website`, `project`
2. `enabled`: `true`, `false`
3. `path location`: inside workspace root vs outside
4. `upstream_url`: present vs absent
5. `type`: `proxy`, `unknown`, `static`, `php`

### B) List/detail contract invariants

For every id returned by `/api/tools`:

1. `/api/tools/:id` must not 404 under same filters.
2. `/api/tools/:id/docs` must resolve consistently.
3. Hidden filtering behavior must match list endpoint behavior.

### C) Restart persistence invariants

1. Create manual entries with full metadata (docs/endpoints/routing/tags/deploy).
2. Restart daemon.
3. Verify exact field parity before/after restart.
4. Re-run scan and verify parity again.

### D) Error-path invariants

1. Block Caddy reload/start conditions intentionally (conflict on `:443`).
2. Ensure API returns handled errors (`422/504`) not generic `500`.
3. Ensure retries recover after service reset.

### E) UI/API parity checks

For every field in Add form, confirm:

1. It persists via API.
2. It appears in edit page.
3. It can be updated and saved.
4. Behavior is reflected in list/detail/cards after refresh.

## 4) Suggested Repeatable Command Set

### Quick source-mode loop

```bash
bash dev-down.sh
bash dev-up.sh
```

### Minimal smoke checks

```bash
curl -s http://127.0.0.1:4777/api/system/health | jq .
curl -s http://127.0.0.1:4777/api/projects?include_hidden=true | jq '.data | length'
curl -s http://127.0.0.1:4777/api/tools?include_hidden=true | jq '.data | length'
```

### Manual in-root durability probe (currently failing)

```bash
BASE=http://127.0.0.1:4777
NAME=manual-in-root-$(date +%s)

curl -s -X POST "$BASE/api/projects" \
  -H 'content-type: application/json' \
  -d "{\"name\":\"$NAME\",\"path\":\"/home/ryan/sites/Lantern\",\"kind\":\"service\",\"type\":\"proxy\",\"upstream_url\":\"http://127.0.0.1:4777\"}" | jq .

curl -s "$BASE/api/projects?include_hidden=true" | jq ".data | any(.name==\"$NAME\")"
curl -s -X POST "$BASE/api/projects/scan?include_hidden=true" | jq .
curl -s "$BASE/api/projects?include_hidden=true" | jq ".data | any(.name==\"$NAME\")"
```

Expected: `true` both times.  
Current behavior: second check becomes `false`.
