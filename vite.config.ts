import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

const API_PORT = Number(process.env.PORT) || 3001;

export default defineConfig({
  root: 'client',
  plugins: [react(), tailwindcss()],
  server: {
    port: 5173,
    strictPort: true,
    host: 'localhost',
    proxy: { '/api': `http://127.0.0.1:${API_PORT}` },
  },
  build: {
    outDir: '../dist',
    emptyOutDir: true,
    chunkSizeWarningLimit: 6000,
  },
});
