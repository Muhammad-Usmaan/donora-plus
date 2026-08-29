// Temporary helper: calls a Supabase MCP tool via the streamable HTTP protocol.
// Usage: node mcp_call.js <tool_name> [args.json]  (if omitted, defaults to project-scoped args)
const fs = require('fs');
const config = JSON.parse(fs.readFileSync('C:/Users/LLS/.qoder/mcp.json', 'utf8'));
const token = config.mcpServers.supabase.headers.Authorization;
const url = config.mcpServers.supabase.url;
const PROJECT_REF = 'lrprgqraxcbqbobordyy';

async function post(body, sessionId) {
  const headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json, text/event-stream',
    'Authorization': token,
  };
  if (sessionId) headers['mcp-session-id'] = sessionId;
  const res = await fetch(url, { method: 'POST', headers, body: JSON.stringify(body) });
  const sid = res.headers.get('mcp-session-id');
  const text = await res.text();
  let json = null;
  const dataLine = text.split('\n').find(l => l.startsWith('data:'));
  if (dataLine) { try { json = JSON.parse(dataLine.slice(5).trim()); } catch (e) {} }
  if (!json) { try { json = JSON.parse(text); } catch (e) {} }
  return { status: res.status, sid, json, text };
}

(async () => {
  const toolName = process.argv[2];
  let args = { project_id: PROJECT_REF };
  if (process.argv[3]) {
    if (toolName === 'apply_migration') {
      // node mcp_call.js apply_migration <migration.sql> <name>
      args = {
        project_id: PROJECT_REF,
        name: process.argv[4] || 'migration',
        query: fs.readFileSync(process.argv[3], 'utf8'),
      };
    } else {
      args = JSON.parse(fs.readFileSync(process.argv[3], 'utf8'));
    }
  }
  try {
    const init = await post({ jsonrpc: '2.0', id: 1, method: 'initialize', params: { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'diag', version: '1.0' } } });
    const sid = init.sid;
    await post({ jsonrpc: '2.0', method: 'notifications/initialized' }, sid);
    const result = await post({ jsonrpc: '2.0', id: 2, method: 'tools/call', params: { name: toolName, arguments: args } }, sid);
    if (result.json && result.json.error) {
      console.log('RPC_ERROR: ' + JSON.stringify(result.json.error));
      process.exit(1);
    }
    const content = result.json && result.json.result && result.json.result.content;
    if (content) {
      for (const c of content) {
        if (c.type === 'text') console.log(c.text);
        else console.log(JSON.stringify(c));
      }
    } else {
      console.log(JSON.stringify(result.json));
    }
  } catch (e) {
    console.log('FAILED: ' + e.message);
    process.exit(1);
  }
})();
