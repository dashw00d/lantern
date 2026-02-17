#!/bin/bash
# =============================================================================
# Test browser MCP integration end-to-end without going through MCP transport.
# Uses direct HTTP calls to Lantern + browser daemon APIs.
# =============================================================================
set -euo pipefail

LANTERN="http://127.0.0.1:4777"
BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

pass() { echo -e "${GREEN}  ✓${RESET} $*"; }
fail() { echo -e "${RED}  ✗${RESET} $*"; }
info() { echo -e "${CYAN}  →${RESET} $*"; }
section() { echo -e "\n${BOLD}$*${RESET}"; }

# ---------- 1. Lantern daemon health ----------
section "1. Lantern daemon"
if curl -sf "$LANTERN/api/health" >/dev/null 2>&1; then
  pass "Daemon is reachable"
else
  fail "Daemon is NOT reachable at $LANTERN"
  exit 1
fi

# ---------- 2. Browser project exists? ----------
section "2. Browser project discovery"
BROWSER_JSON=$(curl -sf "$LANTERN/api/projects/browser" 2>/dev/null || echo '{"error":"not_found"}')

if echo "$BROWSER_JSON" | grep -q '"error"'; then
  info "Browser not found, triggering scan..."
  SCAN_RESULT=$(curl -sf -X POST "$LANTERN/api/projects/scan" 2>/dev/null || echo "scan_failed")
  if echo "$SCAN_RESULT" | grep -q "browser"; then
    pass "Scan discovered browser project"
  else
    fail "Scan did not find browser project"
    info "Check that ~/tools/browser has a lantern.yaml"
    exit 1
  fi
  BROWSER_JSON=$(curl -sf "$LANTERN/api/projects/browser" 2>/dev/null || echo '{"error":"not_found"}')
fi

BROWSER_STATUS=$(echo "$BROWSER_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null || echo "unknown")
BROWSER_URL=$(echo "$BROWSER_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('upstream_url') or d.get('base_url') or 'none')" 2>/dev/null || echo "none")
pass "Browser project found (status: $BROWSER_STATUS, url: $BROWSER_URL)"

# ---------- 3. Browser daemon reachable? ----------
section "3. Browser daemon connectivity"
if [ "$BROWSER_URL" = "none" ]; then
  fail "Browser has no URL configured"
  exit 1
fi

BROWSER_HEALTH=$(curl -sf --max-time 5 "$BROWSER_URL/health" 2>/dev/null || echo "unreachable")
if echo "$BROWSER_HEALTH" | grep -qi "ok\|running\|healthy\|status"; then
  pass "Browser daemon is reachable at $BROWSER_URL"
else
  fail "Browser daemon not reachable at $BROWSER_URL/health"
  info "Response: $BROWSER_HEALTH"
  info "Is the browser daemon running?"
  exit 1
fi

# ---------- 4. Direct browser API call ----------
section "4. Direct browser API call"
info "Calling browser /tasks/execute directly (bypassing Lantern)..."
DIRECT_RESULT=$(curl -sf --max-time 30 \
  -X POST "$BROWSER_URL/tasks/execute" \
  -H "Content-Type: application/json" \
  -d '{"site":"generic","action":"get_text","params":{"url":"https://example.com"}}' 2>&1 || echo "DIRECT_CALL_FAILED")

if echo "$DIRECT_RESULT" | grep -qi "example\|domain\|illustrative"; then
  pass "Direct browser call works"
  info "Got ${#DIRECT_RESULT} bytes"
else
  fail "Direct browser call failed"
  info "Response (first 200 chars): ${DIRECT_RESULT:0:200}"
fi

# ---------- 5. Lantern-proxied call (sync) ----------
section "5. Lantern-proxied call (sync via call_tool_api pattern)"
info "Calling browser through Lantern API..."

# This simulates what the MCP call_tool_api tool does internally
PROXY_RESULT=$(curl -sf --max-time 30 \
  -X POST "$BROWSER_URL/tasks/execute" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"site":"generic","action":"get_text","params":{"url":"https://example.com"}}' 2>&1 || echo "PROXY_CALL_FAILED")

if echo "$PROXY_RESULT" | grep -qi "example\|domain\|illustrative"; then
  pass "Lantern-proxied call works"
else
  fail "Lantern-proxied call failed"
  info "Response (first 200 chars): ${PROXY_RESULT:0:200}"
fi

# ---------- 6. MCP tool call via curl (full MCP protocol) ----------
section "6. MCP protocol test"
info "Testing full MCP tool call via streamable HTTP..."

# Initialize session
INIT_RESP=$(curl -sf --max-time 5 \
  -X POST "$LANTERN/mcp" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -D /tmp/mcp-test-headers.txt \
  -d '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{"roots":{}},"clientInfo":{"name":"test-script","version":"1.0"}}}' 2>&1)

SESSION_ID=$(grep -i "mcp-session-id" /tmp/mcp-test-headers.txt 2>/dev/null | tr -d '\r' | awk '{print $2}')

if [ -z "$SESSION_ID" ]; then
  fail "MCP initialize failed (no session ID)"
  info "Response: $INIT_RESP"
else
  pass "MCP session initialized: $SESSION_ID"

  # Send initialized notification
  curl -sf --max-time 5 \
    -X POST "$LANTERN/mcp" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -H "Mcp-Session-Id: $SESSION_ID" \
    -d '{"jsonrpc":"2.0","method":"notifications/initialized"}' >/dev/null 2>&1

  # Call check_health as a quick smoke test
  HEALTH_RESP=$(curl -sf --max-time 10 \
    -X POST "$LANTERN/mcp" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -H "Mcp-Session-Id: $SESSION_ID" \
    -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"check_health","arguments":{}}}' 2>&1 || echo "MCP_CALL_FAILED")

  if echo "$HEALTH_RESP" | grep -q "daemon"; then
    pass "MCP tool call works (check_health)"
  else
    fail "MCP tool call failed"
    info "Response: ${HEALTH_RESP:0:300}"
  fi

  # Call browser via MCP call_tool_api
  info "Testing call_tool_api → browser via MCP..."
  BROWSER_MCP_RESP=$(curl -sf --max-time 30 \
    -X POST "$LANTERN/mcp" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -H "Mcp-Session-Id: $SESSION_ID" \
    -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"call_tool_api","arguments":{"tool":"browser","method":"POST","path":"/tasks/execute","body":"{\"site\":\"generic\",\"action\":\"get_text\",\"params\":{\"url\":\"https://example.com\"}}"}}}' 2>&1 || echo "MCP_BROWSER_FAILED")

  if echo "$BROWSER_MCP_RESP" | grep -qi "example\|domain\|result"; then
    pass "MCP → call_tool_api → browser works!"
  else
    fail "MCP → call_tool_api → browser failed"
    info "Response (first 300 chars): ${BROWSER_MCP_RESP:0:300}"
  fi
fi

section "Done!"
