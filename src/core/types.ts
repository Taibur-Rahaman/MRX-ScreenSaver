export enum Mode {
  SCREENSAVER = 'screensaver',
  PREVIEW = 'preview',
  SETTINGS = 'settings',
}

export interface SceneConfig {
  name: string;
  params: Record<string, any>;
}

export interface AppSettings {
  activeScene: string;
  globalSpeed: number;
  themeColor: string;
}
