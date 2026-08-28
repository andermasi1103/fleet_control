export type HealthResponse = {
  status: 'ok';
};

export type DatabaseHealthResponse = HealthResponse & {
  database: 'connected';
};
