export class Renderer {
  private canvas: HTMLCanvasElement;
  private gl: WebGL2RenderingContext;
  private animationFrameId: number | null = null;

  constructor(canvasId: string) {
    this.canvas = document.getElementById(canvasId) as HTMLCanvasElement;
    const gl = this.canvas.getContext('webgl2');
    if (!gl) {
      throw new Error('WebGL 2 not supported');
    }
    this.gl = gl;
    this.resize();
    window.addEventListener('resize', () => this.resize());
  }

  private resize() {
    this.canvas.width = window.innerWidth;
    this.canvas.height = window.innerHeight;
    this.gl.viewport(0, 0, this.canvas.width, this.canvas.height);
  }

  start(updateFn: (time: number) => void) {
    const loop = (time: number) => {
      updateFn(time);
      this.animationFrameId = requestAnimationFrame(loop);
    };
    this.animationFrameId = requestAnimationFrame(loop);
  }

  stop() {
    if (this.animationFrameId) {
      cancelAnimationFrame(this.animationFrameId);
      this.animationFrameId = null;
    }
  }

  getGL() {
    return this.gl;
  }
}
