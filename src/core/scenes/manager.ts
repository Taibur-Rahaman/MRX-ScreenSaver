import { Mode, SceneConfig } from '../types';

export interface Scene {
  update(time: number, config: SceneConfig): void;
  destroy(): void;
}

export class SceneManager {
  private currentScene: Scene | null = null;
  private scenes: Map<string, new (gl: WebGL2RenderingContext) => Scene> = new Map();
  private gl: WebGL2RenderingContext;

  constructor(gl: WebGL2RenderingContext) {
    this.gl = gl;
  }

  registerScene(name: string, sceneClass: new (gl: WebGL2RenderingContext) => Scene) {
    this.scenes.set(name, sceneClass);
  }

  setScene(name: string, config: SceneConfig) {
    if (this.currentScene) {
      this.currentScene.destroy();
    }

    const SceneClass = this.scenes.get(name);
    if (!SceneClass) {
      console.error(`Scene ${name} not found`);
      return;
    }

    this.currentScene = new SceneClass(this.gl);
    console.log(`Switched to scene: ${name}`);
  }

  update(time: number, config: SceneConfig) {
    if (this.currentScene) {
      this.currentScene.update(time, config);
    }
  }
}
