import { Pool } from 'pg';

import { env } from '../config/env.js';
import { createDatabasePoolConfig } from './pool-config.js';

export const pool = new Pool(createDatabasePoolConfig(env));

type RuntimeDatabaseIdentity = {
  session_user: string;
  current_user: string;
  has_expected_runtime_membership: boolean;
  can_set_fleet_owner: boolean;
  has_unapproved_settable_membership: boolean;
};

export async function assertRuntimeDatabaseIdentity(): Promise<void> {
  const result = await pool.query<RuntimeDatabaseIdentity>(
    `SELECT
       session_user,
       current_user,
       (session_user = 'fleet_app'
        OR EXISTS (
          SELECT 1
          FROM pg_auth_members membership
          JOIN pg_roles granted_role ON granted_role.oid = membership.roleid
          JOIN pg_roles member_role ON member_role.oid = membership.member
          WHERE granted_role.rolname = 'fleet_app'
            AND member_role.rolname = session_user
            AND NOT membership.admin_option
            AND membership.inherit_option
            AND NOT membership.set_option
        )) AS has_expected_runtime_membership,
       pg_has_role(session_user, 'fleet_owner', 'SET') AS can_set_fleet_owner,
       EXISTS (
         SELECT 1
         FROM pg_auth_members membership
         JOIN pg_roles granted_role ON granted_role.oid = membership.roleid
         JOIN pg_roles member_role ON member_role.oid = membership.member
         WHERE member_role.rolname = session_user
           AND granted_role.rolname <> 'fleet_app'
           AND membership.set_option
       ) AS has_unapproved_settable_membership`
  );
  const identity = result.rows[0];
  if (
    identity?.session_user !== identity?.current_user ||
    !identity?.has_expected_runtime_membership ||
    identity.can_set_fleet_owner ||
    identity.has_unapproved_settable_membership
  ) {
    throw new Error('Runtime database login must be fleet_app-only and cannot start under or SET another role.');
  }
}
