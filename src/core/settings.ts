import { AppSettings } from '../types';

type StoreLike = {
  get: <T>(key: string) => Promise<T | null>;
  set: (key: string, value: unknown) => Promise<void>;
  save: () => Promise<void>;
};

/**
 * Settings storage that works in Tauri, browser, and macOS WKWebView (file://).
 * Never statically imports @tauri-apps/* so the screensaver bundle stays offline-safe.
 */
export class SettingsManager {
  private storePromise: Promise<StoreLike> | null = null;
  private cachedSettings: AppSettings | null = null;
  private memory = new Map<string, unknown>();

  private getStore(): Promise<StoreLike> {
    if (!this.storePromise) {
      this.storePromise = this.createStore();
    }
    return this.storePromise;
  }

  private async createStore(): Promise<StoreLike> {
    const injected = (window as unknown as { __MRX_SCREENSAVER__?: { mode?: string } }).__MRX_SCREENSAVER__;
    const mode = injected?.mode;
    // .scr runs from System32 — avoid writing settings beside the binary.
    if (mode === 'screensaver' || mode === 'preview') {
      return {
        get: async (key) =>
          this.memory.has(key) ? (this.memory.get(key) as never) : null,
        set: async (key, value) => {
          this.memory.set(key, value);
        },
        save: async () => {},
      };
    }

    const tauri = (window as unknown as { __TAURI__?: unknown }).__TAURI__;
    if (tauri) {
      try {
        const { Store } = await import('@tauri-apps/plugin-store');
        return new Store('.settings.dat') as unknown as StoreLike;
      } catch {
        // Fall through to local / memory store.
      }
    }

    try {
      const probeKey = '__mrx_probe__';
      localStorage.setItem(probeKey, '1');
      localStorage.removeItem(probeKey);
      return {
        get: async (key) => JSON.parse(localStorage.getItem(key) || 'null'),
        set: async (key, value) => localStorage.setItem(key, JSON.stringify(value)),
        save: async () => {},
      };
    } catch {
      return {
        get: async (key) =>
          this.memory.has(key) ? (this.memory.get(key) as never) : null,
        set: async (key, value) => {
          this.memory.set(key, value);
        },
        save: async () => {},
      };
    }
  }

  async loadSettings(): Promise<AppSettings> {
    if (this.cachedSettings) return this.cachedSettings;

    const store = await this.getStore();
    const saved = await store.get<AppSettings>('app_settings');
    if (saved) {
      this.cachedSettings = saved;
      return saved;
    }

    const defaults: AppSettings = {
      activeScene: 'flipclock',
      globalSpeed: 1.0,
      themeColor: '#ffffff',
    };
    await this.saveSettings(defaults);
    return defaults;
  }

  async saveSettings(settings: AppSettings): Promise<void> {
    const store = await this.getStore();
    await store.set('app_settings', settings);
    await store.save();
    this.cachedSettings = settings;
  }
}
