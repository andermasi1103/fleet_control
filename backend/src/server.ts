import { buildApp } from './app.js';
import { env } from './config/env.js';

const app = await buildApp();

let shuttingDown = false;

async function shutdown(signal: 'SIGINT' | 'SIGTERM'): Promise<void> {
  if (shuttingDown) return;
  shuttingDown = true;
  app.log.info({ signal }, 'Graceful shutdown started');

  try {
    await app.close();
    process.exit(0);
  } catch (error) {
    const shutdownError = error as { name?: string };
    app.log.error({ errorName: shutdownError.name }, 'Graceful shutdown failed');
    process.exit(1);
  }
}

process.once('SIGINT', () => void shutdown('SIGINT'));
process.once('SIGTERM', () => void shutdown('SIGTERM'));

try {
  await app.listen({ host: env.HOST, port: env.PORT });
} catch (error) {
  const startupError = error as { name?: string };
  app.log.error({ errorName: startupError.name }, 'Server failed to start');
  process.exit(1);
}
