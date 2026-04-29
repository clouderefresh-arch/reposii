# Telegram Mini App — стартовый шаблон

Монорепозиторий на pnpm workspaces:

- `apps/web` — фронтенд Mini App (React 18 + Vite + `@telegram-apps/telegram-ui`).
- `apps/api` — backend на Fastify 5 с валидацией `initData` (HMAC-SHA256).
- `apps/bot` — Telegram-бот на grammY (long polling), отправляет кнопку открытия Mini App.
- `packages/shared` — общие zod-схемы и типы (`@app/shared`).

## Установка на macOS

1. Поставь Homebrew (если ещё нет):

   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. Установи nvm и Node 20 LTS:

   ```bash
   brew install nvm
   mkdir -p ~/.nvm
   echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.zshrc
   echo '[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh"' >> ~/.zshrc
   exec zsh
   nvm install 20
   nvm use 20
   ```

3. Установи pnpm:

   ```bash
   corepack enable
   corepack prepare pnpm@latest --activate
   ```

   или:

   ```bash
   brew install pnpm
   ```

4. Установи cloudflared (для HTTPS-туннеля к локальному dev-серверу):

   ```bash
   brew install cloudflared
   ```

5. (Опционально) Docker Desktop, если планируешь упаковывать api/bot в контейнеры:

   ```bash
   brew install --cask docker
   ```

## Первый запуск

1. Создай бота через [@BotFather](https://t.me/BotFather):
   - `/newbot` → задай имя и username, получи `BOT_TOKEN`.
   - `/newapp` (или `/myapps`) → создай Mini App у этого бота, временно укажи любой HTTPS-URL
     (после поднимешь cloudflared и обновишь URL).

2. Скопируй `.env.example` в `.env` в корне репозитория и заполни значения:

   ```bash
   cp .env.example .env
   ```

   - `BOT_TOKEN` — из @BotFather.
   - `WEB_APP_URL` — публичный HTTPS-URL Mini App (cloudflared-туннель в dev, прод-домен в проде).
   - `API_PORT` — порт Fastify (по умолчанию 3001).
   - `API_ALLOWED_ORIGINS` — список origin'ов через запятую, с которых разрешён CORS.
   - `VITE_API_URL` — URL backend для фронта.

   Для фронта продублируй `VITE_API_URL` в `apps/web/.env` (есть `apps/web/.env.example`):

   ```bash
   cp apps/web/.env.example apps/web/.env
   ```

3. Установи зависимости из корня:

   ```bash
   pnpm install
   ```

4. Подними HTTPS-туннель к локальному dev-серверу Vite (порт 5173):

   ```bash
   cloudflared tunnel --url http://localhost:5173
   ```

   Скопируй полученный `https://<random>.trycloudflare.com` URL.

5. Привяжи этот HTTPS-URL к Mini App в @BotFather:
   - `/myapps` → выбери приложение → `Edit Web App URL` → вставь URL из cloudflared.
   - Этот же URL положи в `WEB_APP_URL` в `.env`.

6. Запусти всё параллельно:

   ```bash
   pnpm dev
   ```

   Это поднимет одновременно:
   - `apps/web` на `http://localhost:5173`
   - `apps/api` на `http://localhost:${API_PORT}`
   - `apps/bot` в long polling

   Открой бота в Telegram, отправь `/start`, нажми кнопку — откроется Mini App.

   Отдельные процессы можно запускать так:

   ```bash
   pnpm dev:web
   pnpm dev:api
   pnpm dev:bot
   ```

## Как это работает

1. Telegram открывает Mini App (`apps/web`) внутри встроенного браузера и инжектит
   `window.Telegram.WebApp` со свойством `initData` — подписанной HMAC строкой.
2. Фронт в `apps/web/src/api/client.ts` отправляет `initData` в каждом запросе к backend
   через заголовок `X-Telegram-Init-Data`.
3. `apps/api` в `onRequest`-хуке валидирует подпись:
   - `secret = HMAC_SHA256("WebAppData", BOT_TOKEN)`,
   - `data_check_string` собирается из всех полей кроме `hash`, отсортированных по ключу
     и склеенных через `\n`,
   - вычисленный HMAC сравнивается с `hash` из `initData` через `timingSafeEqual`,
   - проверяется свежесть `auth_date` (по умолчанию не старше 24 часов).
4. На невалидном/отсутствующем `initData` сервер отдаёт `401`. Эндпоинт `/health`
   доступен без проверки.
5. Внутри хендлеров `request.initData.user` уже содержит распарсенного `TelegramUser`
   (типы из `packages/shared`).

## Скрипты

- `pnpm dev` — параллельный запуск web + api + bot.
- `pnpm build` — сборка всех пакетов (Vite для web, tsc для api/bot/shared).
- `pnpm typecheck` — `tsc --noEmit` во всех пакетах.
- `pnpm format` / `pnpm format:check` — Prettier.

## Деплой

- **Frontend (`apps/web`)** — [Vercel](https://vercel.com):
  - Project root: `apps/web`.
  - Build command: `pnpm --filter @app/web... build` (или `pnpm build`).
  - Output: `apps/web/dist`.
  - Env: `VITE_API_URL` = публичный URL backend.
  - В @BotFather укажи итоговый домен Vercel в качестве Web App URL.

- **Backend (`apps/api`) и бот (`apps/bot`)** — [Railway](https://railway.app)
  или [Render](https://render.com):
  - Два отдельных сервиса (web service для api и worker для bot).
  - Install: `pnpm install --frozen-lockfile`.
  - Build api: `pnpm --filter @app/api... build`, start: `pnpm --filter @app/api start`.
  - Build bot: `pnpm --filter @app/bot... build`, start: `pnpm --filter @app/bot start`.
  - Env: скопируй переменные из `.env.example`. У api добавь домен Vercel в
    `API_ALLOWED_ORIGINS`. У bot — продовый `WEB_APP_URL`.

## Структура

```
.
├── apps/
│   ├── api/      Fastify backend + initData validation
│   ├── bot/      grammY long-polling bot
│   └── web/      React + Vite Mini App
├── packages/
│   └── shared/   zod-схемы и типы (@app/shared)
├── package.json
├── pnpm-workspace.yaml
└── tsconfig.base.json
```
