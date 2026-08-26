import { Store } from '@tauri-apps/plugin-store';
import { AppSettings } from '../types';

export class SettingsManager {
  private store: Store;
  private cachedSettings: AppSettings | null = null;

  constructor() {
    this.store = new Store('.settings.dat');
  }

  async loadSettings(): Promise<AppSettings> {
    if (this.cachedSettings) return this.cachedSettings;

    const saved = await this.store.get<AppSettings>('app_settings');
    if (saved) {
      this.cachedSettings = saved;
      return saved;
    }

    // Default settings
    const defaults: AppSettings = {
      activeScene: 'starfield',
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
