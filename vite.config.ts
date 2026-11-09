import { defineConfig } from 'vite';

export default defineConfig({
  // относительные пути — игра работает и на GitHub Pages (/lamplighter/), и в будущем приложении
  base: './',
  server: { host: true, port: 5173 },
  build: { target: 'es2022', chunkSizeWarningLimit: 1500 },
});
