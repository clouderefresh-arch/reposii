import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Section, Cell, Title, Text } from '@telegram-apps/telegram-ui';
import { getTelegram, hapticImpact, getTelegramUser } from '../lib/telegram';

export function HomePage() {
  const navigate = useNavigate();

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

  const user = getTelegramUser();

  return (
    <div className="page">
      <Title weight="2">Telegram Mini App</Title>
      <Text>Стартовый шаблон: React + Vite + Fastify + grammY.</Text>
      <Section header="Состояние">
        <Cell subtitle={user ? `${user.first_name} ${user.last_name ?? ''}`.trim() : '—'}>
          Пользователь Telegram
        </Cell>
        <Cell subtitle={getTelegram() ? 'инициализирован' : 'не запущен из Telegram'}>
          WebApp SDK
        </Cell>
      </Section>
      <Text>Нажми главную кнопку Telegram внизу, чтобы открыть профиль.</Text>
    </div>
  );
}
