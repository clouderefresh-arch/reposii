import { useCallback, useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import {
  Section,
  Cell,
  Title,
  Text,
  Spinner,
  Button,
  Placeholder,
  IconButton,
} from '@telegram-apps/telegram-ui';
import type { Event, Registration } from '@app/shared';
import { getTelegram, hapticImpact } from '../lib/telegram';
import {
  ApiError,
  deleteEvent,
  getEventById,
  listRegistrations,
  registerForEvent,
  unregisterFromEvent,
} from '../api/client';
import { useMe } from '../lib/MeContext';
import { formatEventDate } from '../lib/format';

export function EventPage() {
  const { id: idParam } = useParams<{ id: string }>();
  const id = Number(idParam);
  const navigate = useNavigate();
  const { me } = useMe();

  const [event, setEvent] = useState<Event | null>(null);
  const [registrations, setRegistrations] = useState<Registration[] | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const isOrganizer = me?.isOrganizer ?? false;

  const reload = useCallback(async () => {
    if (!Number.isInteger(id) || id <= 0) {
      setError('Неверный идентификатор события');
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const ev = await getEventById(id);
      setEvent(ev);
      if (isOrganizer) {
        const list = await listRegistrations(id);
        setRegistrations(list.registrations);
      }
    } catch (err) {
      setError(formatError(err));
    } finally {
      setLoading(false);
    }
  }, [id, isOrganizer]);

  useEffect(() => {
    void reload();
  }, [reload]);

  useEffect(() => {
    const tg = getTelegram();
    if (!tg) return;
    const handleBack = () => navigate('/');
    tg.BackButton.show();
    tg.BackButton.onClick(handleBack);
    tg.MainButton.hide();
    return () => {
      tg.BackButton.offClick(handleBack);
      tg.BackButton.hide();
    };
  }, [navigate]);

  useEffect(() => {
    const tg = getTelegram();
    if (!tg || !event) return;

    const inPast = event.startsAt < Date.now();
    const isFull = event.capacity > 0 && event.registeredCount >= event.capacity;

    let handler: (() => void) | null = null;

    if (inPast) {
      tg.MainButton.setText('Событие прошло');
      tg.MainButton.disable();
      tg.MainButton.show();
    } else if (event.isRegistered) {
      handler = () => {
        void handleUnregister();
      };
      tg.MainButton.setText('Отменить запись');
      tg.MainButton.enable();
      tg.MainButton.show();
      tg.MainButton.onClick(handler);
    } else if (isFull) {
      tg.MainButton.setText('Мест нет');
      tg.MainButton.disable();
      tg.MainButton.show();
    } else {
      handler = () => {
        void handleRegister();
      };
      tg.MainButton.setText('Записаться');
      tg.MainButton.enable();
      tg.MainButton.show();
      tg.MainButton.onClick(handler);
    }

    return () => {
      if (handler) tg.MainButton.offClick(handler);
    };
  }, [event]);

  const handleRegister = useCallback(async () => {
    if (!event || busy) return;
    setBusy(true);
    setError(null);
    try {
      const updated = await registerForEvent(event.id);
      setEvent(updated);
      hapticImpact('medium');
    } catch (err) {
      setError(formatError(err));
    } finally {
      setBusy(false);
    }
  }, [event, busy]);

  const handleUnregister = useCallback(async () => {
    if (!event || busy) return;
    setBusy(true);
    setError(null);
    try {
      const updated = await unregisterFromEvent(event.id);
      setEvent(updated);
      hapticImpact('light');
    } catch (err) {
      setError(formatError(err));
    } finally {
      setBusy(false);
    }
  }, [event, busy]);

  const handleDelete = useCallback(async () => {
    if (!event || busy) return;
    if (!window.confirm(`Удалить событие «${event.title}» и все записи на него?`)) return;
    setBusy(true);
    setError(null);
    try {
      await deleteEvent(event.id);
      hapticImpact('medium');
      navigate('/');
    } catch (err) {
      setError(formatError(err));
      setBusy(false);
    }
  }, [event, busy, navigate]);

  if (loading) {
    return (
      <div className="page">
        <div style={{ padding: 24, display: 'flex', justifyContent: 'center' }}>
          <Spinner size="m" />
        </div>
      </div>
    );
  }

  if (!event) {
    return (
      <div className="page">
        <Placeholder
          header="Событие не найдено"
          description={error ?? 'Возможно, оно было удалено'}
          action={<Button onClick={() => navigate('/')}>На главную</Button>}
        />
      </div>
    );
  }

  return (
    <div className="page">
      <Title weight="2">{event.title}</Title>

      <Section header="Когда и где">
        <Cell subtitle={formatEventDate(event.startsAt)}>Дата и время</Cell>
        {event.location ? <Cell subtitle={event.location}>Место</Cell> : null}
        <Cell subtitle={capacityText(event)}>Места</Cell>
        {event.isRegistered ? <Cell subtitle="вы записаны">Статус</Cell> : null}
      </Section>

      {event.description ? (
        <Section header="Описание">
          <div style={{ padding: 12, whiteSpace: 'pre-wrap' }}>{event.description}</div>
        </Section>
      ) : null}

      {error ? (
        <Section header="Ошибка">
          <Cell subtitle={error}>Что-то пошло не так</Cell>
        </Section>
      ) : null}

      {isOrganizer ? (
        <>
          <Section header={`Записались (${registrations?.length ?? 0})`}>
            {registrations === null ? (
              <div style={{ padding: 12 }}>
                <Spinner size="s" />
              </div>
            ) : registrations.length === 0 ? (
              <Cell>Пока никто не записался</Cell>
            ) : (
              registrations.map((r) => (
                <Cell
                  key={r.id}
                  subtitle={
                    [r.user.username ? `@${r.user.username}` : null, `id ${r.user.id}`]
                      .filter(Boolean)
                      .join(' · ')
                  }
                >
                  {`${r.user.first_name}${r.user.last_name ? ' ' + r.user.last_name : ''}`}
                </Cell>
              ))
            )}
          </Section>

          <div style={{ display: 'flex', gap: 8, paddingTop: 4 }}>
            <Button stretched mode="outline" onClick={() => navigate(`/events/${event.id}/edit`)}>
              Редактировать
            </Button>
            <IconButton
              mode="outline"
              size="m"
              onClick={() => {
                void handleDelete();
              }}
              aria-label="Удалить"
            >
              ✕
            </IconButton>
          </div>
        </>
      ) : null}
    </div>
  );
}

function capacityText(event: Event): string {
  if (event.capacity === 0) return `${event.registeredCount} записались (без ограничения)`;
  const left = event.capacity - event.registeredCount;
  return `${event.registeredCount} из ${event.capacity}${left > 0 ? `, осталось ${left}` : ', мест нет'}`;
}

function formatError(err: unknown): string {
  if (err instanceof ApiError) return `${err.status}: ${err.message}`;
  if (err instanceof Error) return err.message;
  return 'Неизвестная ошибка';
}
