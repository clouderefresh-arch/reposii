import { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Section,
  Cell,
  Title,
  Text,
  Input,
  Button,
  Checkbox,
  IconButton,
  Spinner,
  Placeholder,
} from '@telegram-apps/telegram-ui';
import type { Task } from '@app/shared';
import { getTelegram, hapticImpact } from '../lib/telegram';
import {
  ApiError,
  createTask as apiCreateTask,
  deleteTask as apiDeleteTask,
  listTasks as apiListTasks,
  updateTask as apiUpdateTask,
} from '../api/client';

export function HomePage() {
  const navigate = useNavigate();
  const [tasks, setTasks] = useState<Task[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [title, setTitle] = useState('');
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    const tg = getTelegram();
    if (!tg) return;

    const handleClick = () => {
      hapticImpact('medium');
      navigate('/profile');
    };

    tg.MainButton.setText('Открыть профиль');
    tg.MainButton.show();
    tg.MainButton.enable();
    tg.MainButton.onClick(handleClick);
    tg.BackButton.hide();

    return () => {
      tg.MainButton.offClick(handleClick);
      tg.MainButton.hide();
    };
  }, [navigate]);

  const reload = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await apiListTasks();
      setTasks(data.tasks);
    } catch (err) {
      setError(formatError(err));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void reload();
  }, [reload]);

  const handleAdd = useCallback(async () => {
    const trimmed = title.trim();
    if (!trimmed) return;
    setSubmitting(true);
    setError(null);
    try {
      const task = await apiCreateTask(trimmed);
      setTasks((prev) => [task, ...prev]);
      setTitle('');
      hapticImpact('light');
    } catch (err) {
      setError(formatError(err));
    } finally {
      setSubmitting(false);
    }
  }, [title]);

  const handleToggle = useCallback(async (task: Task) => {
    const next = !task.done;
    setTasks((prev) => prev.map((t) => (t.id === task.id ? { ...t, done: next } : t)));
    try {
      const updated = await apiUpdateTask(task.id, { done: next });
      setTasks((prev) => prev.map((t) => (t.id === updated.id ? updated : t)));
      hapticImpact('light');
    } catch (err) {
      setTasks((prev) => prev.map((t) => (t.id === task.id ? task : t)));
      setError(formatError(err));
    }
  }, []);

  const handleDelete = useCallback(async (task: Task) => {
    setTasks((prev) => prev.filter((t) => t.id !== task.id));
    try {
      await apiDeleteTask(task.id);
      hapticImpact('medium');
    } catch (err) {
      setTasks((prev) => [task, ...prev]);
      setError(formatError(err));
    }
  }, []);

  return (
    <div className="page">
      <Title weight="2">Мои задачи</Title>
      <Text>Стартовый шаблон Telegram Mini App с сохранением в SQLite.</Text>

      <Section header="Новая задача">
        <div style={{ padding: 12, display: 'flex', flexDirection: 'column', gap: 8 }}>
          <Input
            placeholder="Что нужно сделать?"
            value={title}
            onChange={(e) => setTitle(e.currentTarget.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                e.preventDefault();
                void handleAdd();
              }
            }}
            disabled={submitting}
          />
          <Button
            stretched
            disabled={submitting || title.trim().length === 0}
            onClick={() => {
              void handleAdd();
            }}
          >
            {submitting ? 'Добавляю…' : 'Добавить'}
          </Button>
        </div>
      </Section>

      {error ? (
        <Section header="Ошибка">
          <Cell subtitle={error}>Что-то пошло не так</Cell>
        </Section>
      ) : null}

      <Section header={`Список (${tasks.length})`}>
        {loading ? (
          <div style={{ padding: 24, display: 'flex', justifyContent: 'center' }}>
            <Spinner size="m" />
          </div>
        ) : tasks.length === 0 ? (
          <Placeholder description="Пока пусто. Добавь первую задачу выше." />
        ) : (
          tasks.map((task) => (
            <Cell
              key={task.id}
              before={
                <Checkbox
                  checked={task.done}
                  onChange={() => {
                    void handleToggle(task);
                  }}
                />
              }
              after={
                <IconButton
                  mode="plain"
                  size="s"
                  onClick={() => {
                    void handleDelete(task);
                  }}
                  aria-label="Удалить"
                >
                  ✕
                </IconButton>
              }
              subtitle={new Date(task.updatedAt).toLocaleString('ru-RU')}
            >
              <span style={task.done ? { textDecoration: 'line-through', opacity: 0.6 } : undefined}>
                {task.title}
              </span>
            </Cell>
          ))
        )}
      </Section>
    </div>
  );
}

function formatError(err: unknown): string {
  if (err instanceof ApiError) return `${err.status}: ${err.message}`;
  if (err instanceof Error) return err.message;
  return 'Неизвестная ошибка';
}
