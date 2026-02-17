#!/bin/bash
# ============================================================================
# End-to-end MCP demo flow test
#
# Validates the exact sequence used in the demo recording:
#   list projects → check health → start browser → browse a page
#
# Prerequisites: Lantern daemon running (bash dev-up.sh)
# Usage: bash test-demo.sh
# ============================================================================
set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
DIM='\033[2m'
RESET='\033[0m'

pass() { echo -e "  ${GREEN}PASS${RESET} $*"; }
fail() { echo -e "  ${RED}FAIL${RESET} $*"; FAILURES=$((FAILURES + 1)); }
info() { echo -e "${BOLD}==>${RESET} $*"; }
step() { echo -e "\n${BOLD}[$1/$TOTAL]${RESET} $2"; }

API="http://127.0.0.1:4777/api"
FAILURES=0
TOTAL=7
SESSION_ID=""
BROWSER_PORT=""
BROWSER_URL=""

# ---- Step 1: Lantern health ----
step 1 "Check Lantern daemon is running"
if HEALTH=$(curl -sf --max-time 3 "${API}/system/health" 2>/dev/null); then
  pass "Lantern daemon healthy"
else
  fail "Cannot reach Lantern daemon"
  echo -e "  ${DIM}Start it with: bash dev-up.sh${RESET}"
  exit 1
fi

# ---- Step 2: List projects (trigger scan if needed) ----
step 2 "List projects"
PROJECTS=$(curl -sf --max-time 5 "${API}/projects" 2>/dev/null)
HAS_BROWSER=$(echo "$PROJECTS" | jq -r '.data[] | select(.name == "browser") | .name' 2>/dev/null)
if [[ -z "$HAS_BROWSER" ]]; then
  # Projects not loaded yet — trigger a scan
  curl -sf --max-time 10 -X POST "${API}/projects/scan" >/dev/null 2>&1
  PROJECTS=$(curl -sf --max-time 5 "${API}/projects" 2>/dev/null)
  HAS_BROWSER=$(echo "$PROJECTS" | jq -r '.data[] | select(.name == "browser") | .name' 2>/dev/null)
fi
COUNT=$(echo "$PROJECTS" | jq -r '.data | length' 2>/dev/null || echo "0")
if [[ -n "$HAS_BROWSER" ]]; then
  pass "Found ${COUNT} projects (browser present)"
else
  fail "Browser project not registered (check workspace_roots in settings)"
fi

# ---- Step 3: Start browser project ----
step 3 "Start browser project"
ACTIVATE_RESULT=$(curl -sf --max-time 30 \
  -X POST "${API}/projects/browser/activate" 2>/dev/null) || true

STATUS=$(echo "$ACTIVATE_RESULT" | jq -r '.data.status // "unknown"' 2>/dev/null)
if [[ "$STATUS" == "running" ]]; then
  pass "Browser project activated"
else
  CHECK=$(curl -sf "${API}/projects/browser" 2>/dev/null | jq -r '.data.status // "unknown"')
  if [[ "$CHECK" == "running" ]]; then
    pass "Browser project already running"
  else
    fail "Browser project status: ${STATUS:-unknown}"
  fi
fi

# Get browser port
BROWSER_PORT=$(curl -sf "${API}/projects/browser" 2>/dev/null | jq -r '.data.port // empty')
if [[ -z "$BROWSER_PORT" ]]; then
  fail "Could not determine browser port"
  exit 1
fi
BROWSER_URL="http://127.0.0.1:${BROWSER_PORT}"

# ---- Step 4: Wait for browser health ----
step 4 "Wait for browser health endpoint"
HEALTHY=false
for i in $(seq 1 20); do
  if curl -sf --max-time 2 "${BROWSER_URL}/health" >/dev/null 2>&1; then
    HEALTHY=true
    break
  fi
  sleep 1
done

if $HEALTHY; then
  pass "Browser daemon healthy at ${BROWSER_URL}"
else
  fail "Browser daemon not responding after 20s"
  # Try to get logs for debugging
  echo -e "  ${DIM}Checking logs...${RESET}"
  curl -sf "${API}/projects/browser/logs" 2>/dev/null | jq -r '.data.lines[-5:][]' 2>/dev/null || true
fi

# ---- Step 5: Navigate with auto-session ----
step 5 "Navigate to example.com (auto-session)"
GOTO_BODY='{"site":"generic","action":"goto","params":{"url":"https://example.com"}}'

GOTO_RESULT=$(curl -sf --max-time 60 \
  -X POST \
  -H "Content-Type: application/json" \
  -d "$GOTO_BODY" \
  "${BROWSER_URL}/tasks/execute" 2>/dev/null) || true

if [[ -z "$GOTO_RESULT" ]]; then
  fail "No response from tasks/execute"
else
  GOTO_SUCCESS=$(echo "$GOTO_RESULT" | jq -r '.task.result.success // false' 2>/dev/null)
  SESSION_ID=$(echo "$GOTO_RESULT" | jq -r '.session.id // empty' 2>/dev/null)
  PAGE_URL=$(echo "$GOTO_RESULT" | jq -r '.task.result.data.url // "unknown"' 2>/dev/null)

  if [[ "$GOTO_SUCCESS" == "true" ]]; then
    pass "Navigated to ${PAGE_URL}"
    if [[ -n "$SESSION_ID" ]]; then
      pass "Auto-session created: ${SESSION_ID}"
    else
      fail "No auto-session returned in response"
    fi
  else
    ERROR=$(echo "$GOTO_RESULT" | jq -r '.task.error // .task.result.error // "unknown"' 2>/dev/null)
    fail "goto failed: ${ERROR}"
    echo -e "  ${DIM}$(echo "$GOTO_RESULT" | jq -c '.' 2>/dev/null)${RESET}"
  fi
fi

# ---- Step 6: Get page text (reusing session) ----
step 6 "Extract page content (reusing session)"
if [[ -n "$SESSION_ID" ]]; then
  TEXT_BODY=$(jq -n --arg sid "$SESSION_ID" '{
    session_id: $sid,
    site: "generic",
    action: "get_text",
    params: {selector: "h1"}
  }')

  TEXT_RESULT=$(curl -sf --max-time 15 \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$TEXT_BODY" \
    "${BROWSER_URL}/tasks/execute" 2>/dev/null) || true

  TEXT_OK=$(echo "$TEXT_RESULT" | jq -r '.task.result.success // false' 2>/dev/null)
  TEXT_VAL=$(echo "$TEXT_RESULT" | jq -r '.task.result.data.text // .task.result.data.value // "empty"' 2>/dev/null)

  if [[ "$TEXT_OK" == "true" ]]; then
    pass "Extracted text: '${TEXT_VAL}'"
  else
    ERROR=$(echo "$TEXT_RESULT" | jq -r '.task.error // .task.result.error // "unknown"' 2>/dev/null)
    fail "get_text failed: ${ERROR}"
  fi
else
  fail "Skipped — no session available"
fi

# ---- Step 7: Cleanup ----
step 7 "Cleanup"
if [[ -n "$SESSION_ID" ]]; then
  curl -sf --max-time 5 -X DELETE "${BROWSER_URL}/sessions/${SESSION_ID}" >/dev/null 2>&1 || true
  pass "Session ${SESSION_ID} closed"
fi

# Stop browser project
curl -sf --max-time 10 -X POST "${API}/projects/browser/deactivate" >/dev/null 2>&1 || true
pass "Browser project deactivated"

# ---- Summary ----
echo ""
echo -e "${BOLD}$(printf '%.0s─' {1..50})${RESET}"
if [[ $FAILURES -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}All ${TOTAL} steps passed!${RESET} Demo flow is ready."
else
  echo -e "${RED}${BOLD}${FAILURES} step(s) failed.${RESET} Fix issues before recording."
fi
echo ""

exit $FAILURES
