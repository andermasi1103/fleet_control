import type { preHandlerHookHandler } from 'fastify';
import type { QueryResultRow } from 'pg';

export type DatabaseQueryResult<Row extends QueryResultRow = QueryResultRow> = {
  rows: Row[];
  rowCount: number | null;
};

export interface Database {
  query<Row extends QueryResultRow = QueryResultRow>(
    text: string,
    values?: unknown[]
  ): Promise<DatabaseQueryResult<Row>>;
}

export type FleetSession = {
  sessionId: string;
  userId: string;
  username: string;
  roleId: string;
  roleCode: string;
  companyId: string | null;
  expiresAt: string;
};

declare module 'fastify' {
  interface FastifyRequest {
    fleetSession: FleetSession | null;
  }

  interface FastifyInstance {
    requireFleetSession: preHandlerHookHandler;
  }
}
