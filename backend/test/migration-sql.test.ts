import assert from 'node:assert/strict';
import test from 'node:test';

import { prepareMigrationSql, removeOuterTransactionWrapper } from '../scripts/migration-sql.js';

test('removes a migration-level BEGIN and COMMIT without touching SQL bodies', () => {
  const sql = `-- historical migration
begin;
create function public.example() returns void language plpgsql as $$
begin
  perform 1;
end;
$$;
commit;
`;

  assert.equal(
    removeOuterTransactionWrapper(sql),
    `-- historical migration
create function public.example() returns void language plpgsql as $$
begin
  perform 1;
end;
$$;
`
  );
});

test('leaves a migration without an outer transaction wrapper unchanged', () => {
  const sql = 'create table public.example (id integer);\n';

  assert.equal(removeOuterTransactionWrapper(sql), sql);
});

test('rejects transaction control that remains after normalization', () => {
  assert.throws(
    () => prepareMigrationSql('begin;\ncreate table public.example (id integer);\ncommit;\nselect 1 / 0;\n'),
    /must not contain BEGIN, COMMIT, or ROLLBACK/
  );
});
