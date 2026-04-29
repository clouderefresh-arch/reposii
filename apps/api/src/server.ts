import { loadEnv } from './lib/loadEnv.js';
loadEnv();

import Fastify from 'fastify';
import cors from '@fastify/cors';
import type { MeResponse } from '@app/shared';
import { InitDataError, validateInitData, type ValidatedInitData } from './lib/validateInitData.js';

declare module 'fastify' {
  interface FastifyRequest {
    initData?: ValidatedInitData;
  }
}

const BOT_TOKEN = process.env.BOT_TOKEN ?? '';
const API_PORT = Number.parseInt(process.env.API_PORT ?? '3001', 10);
const ALLOWED_ORIGINS = (process.env.API_ALLOWED_ORIGINS ?? '')
  .split(',')
  .map((s) => s.trim())
  .filter((s) => s.length > 0);

const PUBLIC_ROUTES = new Set<string>(['/health']);

async function buildServer() {
  const app = Fastify({
    logger: {
      level: process.env.LOG_LEVEL ?? 'info',
    },
  });

  await app.register(cors, {
    origin: ALLOWED_ORIGINS.length > 0 ? ALLOWED_ORIGINS : false,
    credentials: true,
    allowedHeaders: ['Content-Type', 'X-Telegram-Init-Data'],
  });

  app.addHook('onRequest', async (request, reply) => {
    const url = request.routeOptions?.url ?? request.url.split('?')[0] ?? request.url;
    if (PUBLIC_ROUTES.has(url)) {
      return;
    }
    if (request.method === 'OPTIONS') {
      return;
    }

    const header = request.headers['x-telegram-init-data'];
    const initData = Array.isArray(header) ? header[0] : header;
    if (!initData) {
      reply.code(401).send({ error: 'unauthorized', message: 'X-Telegram-Init-Data is required' });
      return reply;
    }

    if (!BOT_TOKEN) {
      reply.code(500).send({ error: 'server_misconfigured', message: 'BOT_TOKEN is not set' });
      return reply;
    }

    try {
      request.initData = validateInitData(initData, BOT_TOKEN);
    } catch (err) {
      const code = err instanceof InitDataError ? err.code : 'invalid_init_data';
      const message = err instanceof Error ? err.message : 'invalid initData';
      reply.code(401).send({ error: code, message });
      return reply;
    }
    return;
  });

  app.get('/health', async () => ({ status: 'ok' }));

  app.get('/me', async (request, reply): Promise<MeResponse> => {
    const data = request.initData;
    if (!data) {
      reply.code(401).send({ error: 'unauthorized' });
      return reply as never;
    }
    const response: MeResponse = {
      user: data.user,
      authDate: data.authDate,
    };
    return response;
  });

  return app;
}

async function main() {
  const app = await buildServer();
  try {
    const host = process.env.API_HOST ?? '127.0.0.1';
    await app.listen({ port: API_PORT, host });
  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }
}

void main();
