# MCP Testing & Debugging Guide

## The core problem with AI agents testing MCP
You CANNOT detect when an MCP tool call is hanging. From your perspective it's just "in progress." The user has to sit there for minutes before cancelling. So NEVER use MCP tool calls to diagnose MCP issues.

## When an MCP tool call returns an error

**DO:**
- Check `tail -50 /tmp/lantern-daemon.log` for the actual error
- Check the specific service's logs if it's a call_tool_api error
- Ask the user what they see

**DO NOT:**
- Assume the daemon is broken or stale
- Kill processes on port 4777
- Restart the daemon
- Re-call the same MCP tool that just failed

A 500 from `call_tool_api` usually means the downstream tool (e.g. browser) returned an error, NOT that Lantern is broken.

## How to test the browser integration (layer by layer)

### Layer 1: Is Lantern running?
```bash
curl -s http://127.0.0.1:4777/api/health
```

### Layer 2: Is the browser project registered?
```bash
curl -s http://127.0.0.1:4777/api/projects/browser
```
If not found, trigger a scan:
```bash
curl -s -X POST http://127.0.0.1:4777/api/projects/scan
```

### Layer 3: Is the browser daemon reachable?
Get the URL from layer 2 response (`upstream_url` or `base_url`), then:
```bash
curl -s --max-time 5 http://127.0.0.1:<browser-port>/health
```

### Layer 4: Does a direct browser call work?
```bash
curl -s --max-time 30 -X POST http://127.0.0.1:<browser-port>/tasks/execute \
  -H "Content-Type: application/json" \
  -d '{"site":"generic","action":"get_text","params":{"url":"https://example.com"}}'
```

### Layer 5: Does it work through Lantern's MCP?
Only after layers 1-4 pass. Ask the user to test via MCP since it might hang and you can't detect that.

## After restarting the daemon
The MCP session becomes stale. Tell the user to run `/mcp` to reconnect. Without this, every MCP tool call will hang indefinitely. You have NO way to detect this.

## Common mistakes to avoid
1. **Seeing "port already in use" in logs after a failed restart** — this means YOUR restart attempt failed, not a stale process. The original daemon is still running fine.
2. **Killing the daemon without asking** — always ask before killing anything on port 4777.
3. **Testing MCP by calling MCP tools** — this is circular. Use curl.
4. **Assuming the daemon crashed when a tool call fails** — check the logs first.
