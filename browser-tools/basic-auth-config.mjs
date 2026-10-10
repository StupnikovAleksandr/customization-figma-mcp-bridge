export function buildConfig(site, credentials) {
  const config = {
    browser: {
      browserName: 'chromium',
      isolated: true,
      contextOptions: {},
    },
  };
  const raw = site?.url;
  if (raw !== undefined && typeof raw !== 'string') throw new Error('The dev URL must be a string.');
  if (!raw?.trim()) return config;
  let url;
  try { url = new URL(raw.trim()); } catch { throw new Error('Set a valid absolute dev URL in .local/dev-site.json.'); }
  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password) {
    throw new Error('Use an http(s) URL without credentials in the address.');
  }
  if (typeof credentials?.username !== 'string' || !credentials.username ||
      typeof credentials?.password !== 'string' || !credentials.password) {
    throw new Error('Fill in username and password in .local/dev-site.json or save credentials using configure-basic-auth.ps1.');
  }
  config.browser.contextOptions.httpCredentials = {
    origin: url.origin,
    username: credentials.username,
    password: credentials.password,
  };
  return config;
}
