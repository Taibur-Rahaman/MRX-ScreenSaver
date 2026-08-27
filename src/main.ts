import { Renderer } from './core/renderer';
import { SceneManager } from './core/scenes/manager';
import { StarfieldScene } from './core/scenes/starfield';
import { FlipClockScene } from './core/scenes/flipclock';
import { Mode, SceneConfig } from './core/types';
import { SettingsManager } from './core/settings';

async function init() {
  const renderer = new Renderer('screensaver-canvas');
  const gl = renderer.getGL();

  const sceneManager = new SceneManager(gl);
  (window as any).sceneManager = sceneManager;
  sceneManager.registerScene('starfield', StarfieldScene);
  sceneManager.registerScene('flipclock', FlipClockScene);

  const settingsManager = new SettingsManager();
  const settings = await settingsManager.loadSettings();

  // Determine mode from URL parameters (set by native shell)
  const params = new URLSearchParams(window.location.search);
  const mode = (params.get('mode') as Mode) || Mode.SCREENSAVER;

  // Use URL override or saved settings
  const sceneName = params.get('scene') || settings.activeScene;
  const speed = parseFloat(params.get('speed') || settings.globalSpeed.toString());

  console.log(`Starting in ${mode} mode with scene ${sceneName}`);

  const config: SceneConfig = {
    name: sceneName,
    params: {
      speed: speed,
    },
  };

  sceneManager.setScene(sceneName, config);

  if (mode === Mode.SETTINGS) {
    // Simple settings UI for demo
    const ui = document.createElement('div');
    ui.id = 'settings-ui';
    ui.style.position = 'absolute';
    ui.style.top = '20px';
    ui.style.left = '20px';
    ui.style.color = 'white';
    ui.style.background = 'rgba(0,0,0,0.8)';
    ui.style.padding = '20px';
    ui.innerHTML = `
      <h2>Screensaver Settings</h2>
      <label>Scene:
        <select id="scene-select">
          <option value="starfield" ${sceneName === 'starfield' ? 'selected' : ''}>Starfield</option>
          <option value="flipclock" ${sceneName === 'flipclock' ? 'selected' : ''}>Flip Clock</option>
        </select>
      </label><br><br>
      <label>Speed: <input type="range" id="speed-range" min="0.1" max="5" step="0.1" value="${speed}"></label>
      <button id="save-settings">Save</button>
    `;
    document.body.appendChild(ui);

    document.getElementById('save-settings')?.addEventListener('click', async () => {
      const newScene = (document.getElementById('scene-select') as HTMLSelectElement).value;
      const newSpeed = parseFloat((document.getElementById('speed-range') as HTMLInputElement).value);
      await settingsManager.saveSettings({
        ...settings,
        activeScene: newScene,
        globalSpeed: newSpeed,
      });
      alert('Settings saved!');
    });
  }

  renderer.start((time) => {
    sceneManager.update(time, config);
  });
}

init().catch(console.error);
