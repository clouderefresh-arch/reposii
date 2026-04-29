import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Section, Cell, Title, Spinner, Text } from '@telegram-apps/telegram-ui';
import type { MeResponse } from '@app/shared';
import { getTelegram, getTelegramUser } from '../lib/telegram';
import { getMe, ApiError } from '../api/client';

export function ProfilePage() {
  const navigate = useNavigate();
  const [me, setMe] = useState<MeResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const tg = getTelegram();
    if (!tg) return;

    const handleBack = () => {
      navigate('/');
    };

    tg.BackButton.show();
    tg.BackButton.onClick(handleBack);
    tg.MainButton.hide();

    return () => {
      tg.BackButton.offClick(handleBack);
      tg.BackButton.hide();
    };
  }, [navigate]);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);
    getMe()
      .then((data) => {
        if (!cancelled) setMe(data);
      })
      .catch((err: unknown) => {
        if (cancelled) return;
        if (err instanceof ApiError) {
          setError(`${err.status}: ${err.message}`);
        } else if (err instanceof Error) {
          setError(err.message);
        } else {
          setError('Неизвестная ошибка');
        }
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const tgUser = getTelegramUser();

  return (
    <div className="page">
      <Title weight="2">Профиль</Title>

      <Section header="Данные из Telegram WebApp">
        {tgUser ? (
          <>
            <Cell subtitle={String(tgUser.id)}>ID</Cell>
            <Cell subtitle={`${tgUser.first_name} ${tgUser.last_name ?? ''}`.trim()}>Имя</Cell>
            {tgUser.username ? <Cell subtitle={`@${tgUser.username}`}>Username</Cell> : null}
            {tgUser.language_code ? (
              <Cell subtitle={tgUser.language_code}>Язык</Cell>
            ) : null}
          </>
        ) : (
          <Cell>Mini App запущен вне Telegram</Cell>
        )}
      </Section>

      <Section header="Ответ /me от backend">
        {loading ? (
          <div style={{ padding: 16, display: 'flex', justifyContent: 'center' }}>
            <Spinner size="m" />
          </div>
        ) : error ? (
          <Cell subtitle={error}>Ошибка</Cell>
        ) : me ? (
          <pre className="code">{JSON.stringify(me, null, 2)}</pre>
        ) : (
          <Cell>Нет данных</Cell>
        )}
      </Section>

      {!getTelegram() ? (
        <Text>
          Подсказка: открой это приложение через Telegram-бот, чтобы появилась нативная BackButton.
        </Text>
      ) : null}
    </div>
  );
}
