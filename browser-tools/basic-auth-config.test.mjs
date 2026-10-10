import test from 'node:test';
import assert from 'node:assert/strict';
import { buildConfig } from './basic-auth-config.mjs';

test('no URL means no credentials and an isolated session', () => {
  const config = buildConfig({ url: '' }, { username: 'test', password: 'secret' });
  assert.equal(config.browser.isolated, true);
  assert.equal(config.browser.contextOptions.httpCredentials, undefined);
});
test('credentials are restricted to the precise origin, including port', () => {
  const config = buildConfig({ url: 'https://dev.example.ru:8443/about?test=1' }, { username: 'test', password: 'secret' });
  assert.deepEqual(config.browser.contextOptions.httpCredentials, {
    origin: 'https://dev.example.ru:8443', username: 'test', password: 'secret',
  });
});
test('invalid URLs and embedded credentials are rejected', () => {
  for (const url of ['example.ru', 'file:///C:/test', 'https://user:secret@example.ru', 'javascript:alert(1)', 42]) {
    assert.throws(() => buildConfig({ url }, { username: 'test', password: 'secret' }));
  }
});
test('a configured site requires complete credentials', () => {
  assert.throws(() => buildConfig({ url: 'https://dev.example.ru' }));
  assert.throws(() => buildConfig({ url: 'https://dev.example.ru' }, { username: 'test', password: '' }));
});
