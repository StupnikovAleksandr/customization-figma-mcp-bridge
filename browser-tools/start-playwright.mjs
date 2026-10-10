import { readFile } from 'node:fs/promises';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
import { StdioServerTransport } from '../figma-mcp-bridge/server/node_modules/@modelcontextprotocol/sdk/dist/esm/server/stdio.js';
import { buildConfig } from './basic-auth-config.mjs';

const require = createRequire(import.meta.url);
const { createConnection } = require('@playwright/mcp');
const execFileAsync = promisify(execFile);

try {
  let site = {};
  try {
    const raw = await readFile(new URL('./.local/dev-site.json', import.meta.url), 'utf8');
    site = JSON.parse(raw.replace(/^\uFEFF/, ''));
  } catch (error) {
    if (error.code !== 'ENOENT') throw new Error('Unable to read .local/dev-site.json. Check its JSON format.');
  }
  // Validate URL before accessing the secret. Without a URL no credentials are loaded.
  let config;
  if (typeof site.url === 'string' && site.url.trim()) {
    buildConfig(site, { username: 'validation', password: 'validation' });
    let credentials;
    if (Object.hasOwn(site, 'username') || Object.hasOwn(site, 'password')) {
      credentials = { username: site.username, password: site.password };
    } else {
      let output;
      try {
        output = await execFileAsync('powershell.exe', [
          '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
          '-File', fileURLToPath(new URL('./read-basic-auth.ps1', import.meta.url)),
        ], { windowsHide: true, timeout: 15000, maxBuffer: 65536 });
      } catch {
        throw new Error('Basic Auth credentials are unavailable. Run configure-basic-auth.ps1 as the current Windows user.');
      }
      try { credentials = JSON.parse(output.stdout.replace(/^\uFEFF/, '')); }
      catch { throw new Error('Unable to read the saved Basic Auth credentials. Run configure-basic-auth.ps1 again.'); }
    }
    config = buildConfig(site, credentials);
    console.error(`Basic Auth enabled only for ${new URL(site.url.trim()).origin}`);
  } else {
    config = buildConfig(site);
    console.error('Dev URL is not set. Starting Playwright without Basic Auth.');
  }
  const server = await createConnection(config);
  await server.connect(new StdioServerTransport());
  process.stdin.on('end', () => void server.close());
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
