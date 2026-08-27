import { defineConfig } from 'vite';

export default defineConfig({
  root: 'src',
  // Relative asset URLs so the build works under file:// in the macOS .saver WKWebView.
  base: './',
  build: {
    outDir: '../dist',
    emptyOutDir: true,
  },
  server: {
    port: 1420,
    strictPort: true,
  },
});
