import { mkdirSync } from 'node:fs';
import { dirname, isAbsolute, resolve } from 'node:path';
import Database, { type Database as DatabaseType } from 'better-sqlite3';
import type { Task } from '@app/shared';

let db: DatabaseType | null = null;

function resolveDbPath(): string {
  const raw = process.env.DATABASE_PATH ?? './data/app.sqlite';
  return isAbsolute(raw) ? raw : resolve(process.cwd(), raw);
}

export function getDb(): DatabaseType {
  if (db) return db;

  const path = resolveDbPath();
  mkdirSync(dirname(path), { recursive: true });
  db = new Database(path);
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');
  db.exec(`
    CREATE TABLE IF NOT EXISTS tasks (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id    INTEGER NOT NULL,
      title      TEXT NOT NULL,
      done       INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_tasks_user_id ON tasks(user_id);
  `);
  return db;
}

interface TaskRow {
  id: number;
  user_id: number;
  title: string;
  done: number;
  created_at: number;
  updated_at: number;
}

function rowToTask(row: TaskRow): Task {
  return {
    id: row.id,
    userId: row.user_id,
    title: row.title,
    done: row.done === 1,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function listTasks(userId: number): Task[] {
  const rows = getDb()
    .prepare<[number], TaskRow>(
      'SELECT id, user_id, title, done, created_at, updated_at FROM tasks WHERE user_id = ? ORDER BY done ASC, created_at DESC',
    )
    .all(userId);
  return rows.map(rowToTask);
}

export function createTask(userId: number, title: string): Task {
  const now = Date.now();
  const result = getDb()
    .prepare(
      'INSERT INTO tasks (user_id, title, done, created_at, updated_at) VALUES (?, ?, 0, ?, ?)',
    )
    .run(userId, title, now, now);
  const id = Number(result.lastInsertRowid);
  return {
    id,
    userId,
    title,
    done: false,
    createdAt: now,
    updatedAt: now,
  };
}

export function updateTask(
  userId: number,
  id: number,
  patch: { title?: string; done?: boolean },
): Task | null {
  const existing = getDb()
    .prepare<[number, number], TaskRow>(
      'SELECT id, user_id, title, done, created_at, updated_at FROM tasks WHERE id = ? AND user_id = ?',
    )
    .get(id, userId);
  if (!existing) return null;

  const nextTitle = patch.title ?? existing.title;
  const nextDone = patch.done === undefined ? existing.done === 1 : patch.done;
  const now = Date.now();
  getDb()
    .prepare('UPDATE tasks SET title = ?, done = ?, updated_at = ? WHERE id = ? AND user_id = ?')
    .run(nextTitle, nextDone ? 1 : 0, now, id, userId);
  return {
    id,
    userId,
    title: nextTitle,
    done: nextDone,
    createdAt: existing.created_at,
    updatedAt: now,
  };
}

export function deleteTask(userId: number, id: number): boolean {
  const result = getDb()
    .prepare('DELETE FROM tasks WHERE id = ? AND user_id = ?')
    .run(id, userId);
  return result.changes > 0;
}
