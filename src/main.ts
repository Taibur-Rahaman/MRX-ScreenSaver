import { Renderer } from './core/renderer';
import { SceneManager } from './core/scenes/manager';
import { StarfieldScene } from './core/scenes/starfield';
import { FlipClockScene } from './core/scenes/flipclock';
import { AppSettings, Mode, SceneConfig } from './core/types';
import { SettingsManager } from './core/settings';

const DEFAULT_SETTINGS: AppSettings = {
  activeScene: 'flipclock',
  globalSpeed: 1.0,
  themeColor: '#ffffff',
};

function readInjected() {
  return (window as unknown as { __MRX_SCREENSAVER__?: { mode?: string; scene?: string; speed?: string | number } })
    .__MRX_SCREENSAVER__;
}

function resolveSceneName(injected: ReturnType<typeof readInjected>, params: URLSearchParams, hash: URLSearchParams | null, fallback: string) {
  return params.get('scene') || hash?.get('scene') || injected?.scene || fallback;
}

function resolveMode(injected: ReturnType<typeof readInjected>, params: URLSearchParams, hash: URLSearchParams | null) {
  return (params.get('mode') as Mode) || (hash?.get('mode') as Mode) || (injected?.mode as Mode) || Mode.SCREENSAVER;
}

/** Wait until the host window has non-zero dimensions (common in desk.cpl preview embed). */
function waitForViewport(timeoutMs = 4000): Promise<void> {
  return new Promise((resolve) => {
    const start = performance.now();
    const tick = () => {
      if (window.innerWidth > 0 && window.innerHeight > 0) {
        resolve();
        return;
      }
      if (performance.now() - start >= timeoutMs) {
        resolve();
        return;
      }
      requestAnimationFrame(tick);
    };
    tick();
  });
}

function isTauriHost(): boolean {
  return Boolean((window as unknown as { __TAURI__?: unknown }).__TAURI__);
}

function setupWebBanner(sceneName: string) {
  if (isTauriHost()) return;

  const bar = document.createElement('div');
  bar.className = 'web-banner';
  bar.innerHTML = `
    <span class="web-banner-title">MRX ScreenSaver</span>
    <span class="web-banner-scene">${sceneName === 'starfield' ? 'Starfield' : 'Flip Clock'}</span>
    <a href="https://github.com/Taibur-Rahaman/MRX-ScreenSaver/releases/latest" target="_blank" rel="noopener noreferrer">Download</a>
    <a href="?scene=flipclock">Flip Clock</a>
    <a href="?scene=starfield">Starfield</a>
  `;
  document.body.appendChild(bar);
}

/**
 * WebView2 inside a .scr host can throttle or pause rAF.
 * Keep a setInterval fallback so the clock still updates.
 */
function startSceneLoop(sceneManager: SceneManager, config: SceneConfig) {
  let lastFrame = 0;
  const step = (time: number) => {
    sceneManager.update(time, config);
    lastFrame = time;
  };

  const loop = (time: number) => {
    step(time);
    requestAnimationFrame(loop);
  };
  requestAnimationFrame(loop);

  setInterval(() => {
    const now = performance.now();
    if (now - lastFrame > 400) {
      step(now);
    }
  }, 250);
}

async function initFlipClock(config: SceneConfig) {
  const webglCanvas = document.getElementById('screensaver-canvas');
  if (webglCanvas) webglCanvas.style.display = 'none';

  await waitForViewport();

  const sceneManager = new SceneManager(null);
  sceneManager.registerScene('flipclock', FlipClockScene);
  sceneManager.setScene('flipclock', config);
  startSceneLoop(sceneManager, config);
}

async function init() {
  const injected = readInjected();
  const params = new URLSearchParams(window.location.search);
  const hash = window.location.hash.startsWith('#')
    ? new URLSearchParams(window.location.hash.slice(1))
    : null;

  const settingsManager = new SettingsManager();
  // Never block first paint on disk I/O (Tauri store can hang when .scr runs from System32).
  const settingsPromise = settingsManager.loadSettings().catch(() => DEFAULT_SETTINGS);
  const settings = { ...DEFAULT_SETTINGS, ...(await Promise.race([
    settingsPromise,
    new Promise<AppSettings>((resolve) => setTimeout(() => resolve(DEFAULT_SETTINGS), 300)),
  ])) };

  const mode = resolveMode(injected, params, hash);
  const sceneName = resolveSceneName(injected, params, hash, settings.activeScene || 'flipclock');
  const speed = parseFloat(
    params.get('speed') || hash?.get('speed') || String(injected?.speed ?? settings.globalSpeed),
  );

  const config: SceneConfig = { name: sceneName, params: { speed } };

  console.log(`Starting in ${mode} mode with scene ${sceneName}`);
  setupWebBanner(sceneName);

  // Flip clock uses Canvas 2D only — do not require WebGL2 (often fails in .scr host).
  if (sceneName === 'flipclock') {
    await initFlipClock(config);
    return;
  }

  await waitForViewport();

  const renderer = new Renderer('screensaver-canvas');
  const gl = renderer.getGL();
  const sceneManager = new SceneManager(gl);
  (window as unknown as { sceneManager?: SceneManager }).sceneManager = sceneManager;
  sceneManager.registerScene('starfield', StarfieldScene);
  sceneManager.registerScene('flipclock', FlipClockScene);
  sceneManager.setScene(sceneName, config);

  if (mode === Mode.SETTINGS) {
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

init().catch((err) => {
  console.error('MRX ScreenSaver init failed', err);
  document.body.style.background = '#0a0a0a';
  const msg = document.createElement('div');
  msg.style.cssText = 'color:#ccc;font-family:system-ui;padding:24px;text-align:center';
  msg.textContent = 'MRX ScreenSaver failed to start. Install WebView2 Runtime.';
  document.body.appendChild(msg);
});
