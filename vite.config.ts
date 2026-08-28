import { defineConfig } from 'vite';

const base = process.env.VITE_BASE_PATH || './';

export default defineConfig({
  root: 'src',
  publicDir: 'public',
  base,
  build: {
    outDir: '../dist',
    emptyOutDir: true,
  },
  server: {
    port: 1420,
    strictPort: true,
  },
});
