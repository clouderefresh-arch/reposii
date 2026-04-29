import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    host: true,
    port: 5173,
    strictPort: true,
    allowedHosts: [
      '.ngrok-free.app',
      '.ngrok-free.dev',
      '.ngrok.app',
      '.ngrok.dev',
      '.ngrok.io',
      '.trycloudflare.com',
    ],
    headers: {
      'ngrok-skip-browser-warning': 'true',
    },
  },
  build: {
    outDir: 'dist',
    sourcemap: true,
  },
});
