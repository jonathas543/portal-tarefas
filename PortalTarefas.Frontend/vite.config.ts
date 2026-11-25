import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      // porta definida no launchSettings.json da API (perfil https)
      '/api': { target: 'https://localhost:7000', changeOrigin: true, secure: false },
    },
  },
});
