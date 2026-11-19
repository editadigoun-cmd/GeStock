import { test } from 'node:test';
import assert from 'node:assert/strict';
import { hashPassword, verifyPassword, createSessionToken, hashSessionToken } from '../src/services/password.js';

test('PBKDF2 password hashes work within Cloudflare Workers supported iteration limit', async () => {
  const password = 'Test-Password-123!';
  const encoded = await hashPassword(password);
  assert.match(encoded, /^pbkdf2-sha256\$100000\$/);
  assert.equal(await verifyPassword(password, encoded), true);
  assert.equal(await verifyPassword('incorrect-password', encoded), false);
});

test('password verification rejects malformed or unsupported hashes', async () => {
  assert.equal(await verifyPassword('password', 'not-a-hash'), false);
  assert.equal(await verifyPassword('password', 'pbkdf2-sha256$310000$abc$def'), false);
});

test('session tokens are random bearer secrets and are stored as hashes', async () => {
  const token = createSessionToken();
  assert.equal(token.length, 43);
  assert.notEqual(await hashSessionToken(token), token);
  assert.notEqual(token, createSessionToken());
});
