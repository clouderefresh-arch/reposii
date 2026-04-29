import {
  MeResponseSchema,
  TaskListResponseSchema,
  TaskSchema,
  type MeResponse,
  type Task,
  type TaskListResponse,
} from '@app/shared';
import { z } from 'zod';
import { getInitData } from '../lib/telegram';

const RAW_API_URL = import.meta.env.VITE_API_URL ?? '';
const API_URL = RAW_API_URL.replace(/\/$/, '');

export class ApiError extends Error {
  public readonly status: number;
  public readonly code: string | undefined;
  constructor(status: number, message: string, code?: string) {
    super(message);
    this.status = status;
    this.code = code;
    this.name = 'ApiError';
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const headers = new Headers(init?.headers ?? {});
  headers.set('Content-Type', 'application/json');
  const initData = getInitData();
  if (initData) {
    headers.set('X-Telegram-Init-Data', initData);
  }

  const res = await fetch(`${API_URL}${path}`, { ...init, headers });
  const text = await res.text();
  const data: unknown = text.length > 0 ? JSON.parse(text) : null;

  if (!res.ok) {
    let message = `Request failed with ${res.status}`;
    let code: string | undefined;
    if (data && typeof data === 'object') {
      const obj = data as Record<string, unknown>;
      if (typeof obj.message === 'string' && obj.message.length > 0) {
        message = obj.message;
      }
      if (typeof obj.error === 'string') {
        code = obj.error;
      }
    }
    throw new ApiError(res.status, message, code);
  }

  return data as T;
}

export async function getMe(): Promise<MeResponse> {
  const data = await request<unknown>('/me');
  return MeResponseSchema.parse(data);
}

export async function getHealth(): Promise<{ status: string }> {
  return request<{ status: string }>('/health');
}

const TaskEnvelopeSchema = z.object({ task: TaskSchema });

export async function listTasks(): Promise<TaskListResponse> {
  const data = await request<unknown>('/tasks');
  return TaskListResponseSchema.parse(data);
}

export async function createTask(title: string): Promise<Task> {
  const data = await request<unknown>('/tasks', {
    method: 'POST',
    body: JSON.stringify({ title }),
  });
  return TaskEnvelopeSchema.parse(data).task;
}

export async function updateTask(
  id: number,
  patch: { title?: string; done?: boolean },
): Promise<Task> {
  const data = await request<unknown>(`/tasks/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(patch),
  });
  return TaskEnvelopeSchema.parse(data).task;
}

export async function deleteTask(id: number): Promise<void> {
  await request<unknown>(`/tasks/${id}`, { method: 'DELETE' });
}
