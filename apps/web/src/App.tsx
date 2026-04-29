import { Routes, Route, Link } from 'react-router-dom';
import { Placeholder, Button } from '@telegram-apps/telegram-ui';
import { HomePage } from './pages/HomePage';
import { ProfilePage } from './pages/ProfilePage';

function NotFoundPage() {
  return (
    <Placeholder
      header="404"
      description="Страница не найдена"
      action={
        <Link to="/">
          <Button>На главную</Button>
        </Link>
      }
    />
  );
}

export function App() {
  return (
    <Routes>
      <Route path="/" element={<HomePage />} />
      <Route path="/profile" element={<ProfilePage />} />
      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  );
}
