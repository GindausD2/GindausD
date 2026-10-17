// Runs only against a disposable PostgreSQL database. Never use production here.
import { execFile, execFileSync } from 'node:child_process';
import { promisify } from 'node:util';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
if (process.env.MAX_DISPOSABLE_DB !== 'true') throw Error('Set MAX_DISPOSABLE_DB=true for an isolated test database');
const args = ['-X', '-v', 'ON_ERROR_STOP=1', '-At', '-c'];
const sql = statement => execFileSync('psql', [...args, statement], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
const a = '11111111-1111-1111-1111-111111111111';
const b = '22222222-2222-2222-2222-222222222222';
sql(`create role anon; create role authenticated;
create schema auth;
create table auth.users(id uuid primary key);
insert into auth.users values ('${a}'), ('${b}');
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
grant usage on schema auth to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;`);
sql(readFileSync(new URL('../sql/001_usage.sql', import.meta.url), 'utf8'));
const call = id => `set role authenticated; set request.jwt.claim.sub='${id}'; select public.consume_max_request();`;
const exec = promisify(execFile);
// Transaction timestamp is fixed so a wall-clock minute boundary cannot flake the test.
sql(`create function auth.test_now() returns timestamptz language sql stable as $$ select '2026-10-12 12:00:00+00'::timestamptz $$;`);
// Reinstall the same function with only its clock replaced; PostgreSQL locks and grants are unchanged.
const migration = readFileSync(new URL('../sql/001_usage.sql', import.meta.url), 'utf8');
sql(migration.replaceAll('now()', 'auth.test_now()'));
const results = await Promise.all(Array.from({ length: 40 }, () => exec('psql', [...args, call(a)])));
const flags = results.map(r => r.stdout.trim().split('\n').at(-1));
assert.equal(flags.filter(x => x === 't').length, 20);
assert.equal(flags.filter(x => x === 'f').length, 20);
assert.equal(sql(`select string_agg(request_count::text, ',' order by bucket) from public.max_usage where user_id='${a}';`), '20,20');
assert.equal(sql(call(b)).split('\n').at(-1), 't');
assert.equal(sql(`select sum(request_count) from public.max_usage where user_id='${b}';`), '2');
sql(`update public.max_usage set request_count=100 where user_id='${b}' and bucket like 'day:%';`);
assert.equal(sql(call(b)).split('\n').at(-1), 'f');
assert.equal(sql(`select request_count from public.max_usage where user_id='${b}' and bucket like 'minute:%';`), '1');
assert.equal(sql('set role authenticated; select public.consume_max_request();').split('\n').at(-1), 'f');
for (const statement of ['set role anon; select public.consume_max_request();', 'set role authenticated; select * from public.max_usage;', 'set role authenticated; update public.max_usage set request_count=0;']) {
  assert.throws(() => sql(statement), /permission denied/);
}
console.log('PASS: real PostgreSQL concurrent minute cap, daily cap, account isolation, anonymous denial, and direct-table denial');
