import { Client } from './figma-mcp-bridge/server/node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js';
import { StdioClientTransport } from './figma-mcp-bridge/server/node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js';
import { fileURLToPath } from 'node:url';

async function check(name, relativePath, action, args = []) {
  const client = new Client({ name: 'local-setup-check', version: '1.0.0' });
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: [fileURLToPath(new URL(relativePath, import.meta.url)), ...args],
    stderr: 'inherit',
  });
  try {
    await client.connect(transport);
    const { tools } = await client.listTools();
    console.log(`${name}: MCP connected, ${tools.length} tools`);
    await action(client);
  } finally {
    await client.close();
  }
}
await check('figma-bridge', './figma-mcp-bridge/server/dist/index.js', async client => {
  const result = await client.callTool({ name: 'list_files', arguments: {} });
  if (result.isError) throw new Error(JSON.stringify(result));
  console.log('Connected Figma files:', JSON.stringify(result.content));
  console.log('An empty file list is expected until the plugin is opened inside Figma.');
});
await check('playwright', './browser-tools/node_modules/@playwright/mcp/cli.js', async client => {
  const result = await client.callTool({ name: 'browser_navigate', arguments: { url: 'about:blank' } });
  if (result.isError) throw new Error(JSON.stringify(result));
  console.log('Chromium successfully opened about:blank. Dev URL access must be checked separately.');
  await client.callTool({ name: 'browser_close', arguments: {} });
}, ['--browser', 'chromium', '--headless']);
