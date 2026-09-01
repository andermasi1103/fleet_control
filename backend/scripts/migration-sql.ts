const outerTransactionWrapper = /^(?<prefix>(?:\s+|--[^\r\n]*(?:\r?\n|$)|\/\*[\s\S]*?\*\/)*)begin\s*;\s*(?<body>[\s\S]*?)\s*commit\s*;\s*$/i;
const standaloneTransactionControl = /^\s*(?:begin|commit|rollback|start\s+transaction)\s*;\s*(?:--.*)?$/im;

/**
 * Historical migration files wrap their full body in BEGIN/COMMIT while the
 * runner already owns a transaction. Remove only that outer wrapper so an
 * error after the body still rolls back both DDL and schema_migrations.
 */
export function removeOuterTransactionWrapper(sql: string): string {
  const match = sql.match(outerTransactionWrapper);
  if (!match?.groups) return sql;

  const lineEnding = sql.endsWith('\r\n') ? '\r\n' : sql.endsWith('\n') ? '\n' : '';
  return `${match.groups.prefix}${match.groups.body}${lineEnding}`;
}

export function prepareMigrationSql(sourceSql: string): string {
  const sql = removeOuterTransactionWrapper(sourceSql);
  if (standaloneTransactionControl.test(sql)) {
    throw new Error('Migration SQL must not contain BEGIN, COMMIT, or ROLLBACK outside its removable outer wrapper.');
  }
  return sql;
}
