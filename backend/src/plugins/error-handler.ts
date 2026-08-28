import type { FastifyError, FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';

import { env } from '../config/env.js';

type ErrorPayload = {
  error: string;
  message: string;
};

export function registerErrorHandler(app: FastifyInstance): void {
  app.setErrorHandler(
    (error: FastifyError, request: FastifyRequest, reply: FastifyReply): FastifyReply => {
      const statusCode = error.statusCode && error.statusCode >= 400 && error.statusCode < 500
        ? error.statusCode
        : 500;
      const isClientError = statusCode < 500;

      // Log only minimal diagnostic metadata. Payloads and headers can contain secrets.
      request.log.error(
        { errorName: error.name, statusCode, errorCode: error.code },
        'Request failed'
      );

      const payload: ErrorPayload = statusCode === 429
        ? { error: 'rate_limited', message: 'Demasiadas solicitudes. Intenta nuevamente más tarde.' }
        : isClientError
          ? { error: 'bad_request', message: 'Solicitud inválida.' }
          : {
              error: 'internal_error',
              message: env.NODE_ENV === 'production'
                ? 'An unexpected error occurred.'
                : 'An unexpected error occurred. Check the server logs.'
            };

      return reply.status(statusCode).send(payload);
    }
  );
}
