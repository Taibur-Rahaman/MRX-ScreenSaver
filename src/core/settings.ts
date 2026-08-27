import { Store } from '@tauri-apps/plugin-store';
import { AppSettings } from '../types';

export class SettingsManager {
  private store: Store;
  private cachedSettings: AppSettings | null = null;

  constructor() {
    if (window.__TAURI__) {
      this.store = new Store('.settings.dat');
    } else {
      // Mock store for browser development
      this.store = {
        get: async (key: string) => JSON.parse(localStorage.getItem(key) || 'null'),
        set: async (key: string, value: any) => localStorage.setItem(key, JSON.stringify(value)),
        save: async () => {},
      } as any;
    }
  }

  async loadSettings(): Promise<AppSettings> {
    if (this.cachedSettings) return this.cachedSettings;

    const saved = await this.store.get<AppSettings>('app_settings');
    if (saved) {
      this.cachedSettings = saved;
      return saved;
    }

    // Default settings — flip clock is the primary screensaver scene.
    const defaults: AppSettings = {
      activeScene: 'flipclock',
      globalSpeed: 1.0,
      themeColor: '#ffffff',
    };
    await this.saveSettings(defaults);
    return defaults;
  }

  async saveSettings(settings: AppSettings): Promise<void> {
    await this.store.set('app_settings', settings);
    await this.store.save();
    this.cachedSettings = settings;
  }
}
