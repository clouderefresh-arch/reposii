import { loadEnv } from './lib/loadEnv.js';
loadEnv();

import Fastify from 'fastify';
import cors from '@fastify/cors';
import {
  CreateTaskRequestSchema,
  UpdateTaskRequestSchema,
  type MeResponse,
  type TaskListResponse,
} from '@app/shared';
import { InitDataError, validateInitData, type ValidatedInitData } from './lib/validateInitData.js';
import { createTask, deleteTask, getDb, listTasks, updateTask } from './lib/db.js';

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

  app.get('/tasks', async (request, reply): Promise<TaskListResponse> => {
    const data = request.initData;
    if (!data) {
      reply.code(401).send({ error: 'unauthorized' });
      return reply as never;
    }
    return { tasks: listTasks(data.user.id) };
  });

  app.post('/tasks', async (request, reply) => {
    const data = request.initData;
    if (!data) {
      reply.code(401).send({ error: 'unauthorized' });
      return reply;
    }
    const parsed = CreateTaskRequestSchema.safeParse(request.body);
    if (!parsed.success) {
      reply.code(400).send({ error: 'bad_request', message: parsed.error.message });
      return reply;
    }
    const task = createTask(data.user.id, parsed.data.title);
    reply.code(201);
    return { task };
  });

  app.patch<{ Params: { id: string } }>('/tasks/:id', async (request, reply) => {
    const data = request.initData;
    if (!data) {
      reply.code(401).send({ error: 'unauthorized' });
      return reply;
    }
    const id = Number.parseInt(request.params.id, 10);
    if (!Number.isInteger(id) || id <= 0) {
      reply.code(400).send({ error: 'bad_id' });
      return reply;
    }
    const parsed = UpdateTaskRequestSchema.safeParse(request.body);
    if (!parsed.success) {
      reply.code(400).send({ error: 'bad_request', message: parsed.error.message });
      return reply;
    }
    const task = updateTask(data.user.id, id, parsed.data);
    if (!task) {
      reply.code(404).send({ error: 'not_found' });
      return reply;
    }
    return { task };
  });

  app.delete<{ Params: { id: string } }>('/tasks/:id', async (request, reply) => {
    const data = request.initData;
    if (!data) {
      reply.code(401).send({ error: 'unauthorized' });
      return reply;
    }
    const id = Number.parseInt(request.params.id, 10);
    if (!Number.isInteger(id) || id <= 0) {
      reply.code(400).send({ error: 'bad_id' });
      return reply;
    }
    const ok = deleteTask(data.user.id, id);
    if (!ok) {
      reply.code(404).send({ error: 'not_found' });
      return reply;
    }
    reply.code(204);
    return null;
  });

  getDb();

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
