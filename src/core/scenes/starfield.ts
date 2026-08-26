import { Scene, SceneConfig } from '../scenes/manager';

export class StarfieldScene implements Scene {
  private gl: WebGL2RenderingContext;
  private program: WebGLProgram;
  private stars: Float32Array;
  private starCount = 1000;

  constructor(gl: WebGL2RenderingContext) {
    this.gl = gl;
    this.program = this.createProgram();
    this.initStars();
  }

  private createProgram() {
    const vsSource = `#version 300 es
      in vec3 a_position;
      void main() {
        gl_Position = vec4(a_position, 1.0);
        gl_PointSize = 2.0;
      }`;
    const fsSource = `#version 300 es
      precision highp float;
      out vec4 fragColor;
      void main() {
        fragColor = vec4(1.0, 1.0, 1.0, 1.0);
      }`;

    const vs = this.compileShader(this.gl.VERTEX_SHADER, vsSource);
    const fs = this.compileShader(this.gl.FRAGMENT_SHADER, fsSource);
    const program = this.gl.createProgram()!;
    this.gl.attachShader(program, vs);
    this.gl.attachShader(program, fs);
    this.gl.linkProgram(program);
    return program;
  }

  private compileShader(type: number, source: string) {
    const shader = this.gl.createShader(type)!;
    this.gl.shaderSource(shader, source);
    this.gl.compileShader(shader);
    return shader;
  }

  private initStars() {
    this.stars = new Float32Array(this.starCount * 3);
    for (let i = 0; i < this.starCount * 3; i++) {
      this.stars[i] = Math.random() * 2 - 1;
    }
  }

  update(time: number, config: SceneConfig) {
    const speed = config.params.speed || 1.0;
    this.gl.clearColor(0, 0, 0, 1);
    this.gl.clear(this.gl.COLOR_BUFFER_BIT);

    this.gl.useProgram(this.program);
    const positionLoc = this.gl.getAttribLocation(this.program, 'a_position');
    const buffer = this.gl.createBuffer();
    this.gl.bindBuffer(this.gl.ARRAY_BUFFER, buffer);
    this.gl.bufferData(this.gl.ARRAY_BUFFER, this.stars, this.gl.DYNAMIC_DRAW);
    this.gl.enableVertexAttribArray(positionLoc);
    this.gl.vertexAttribPointer(positionLoc, 3, this.gl.FLOAT, false, 0, 0);

    for (let i = 1; i < this.stars.length; i += 3) {
      this.stars[i] += Math.sin(time * 0.001 * speed + i) * 0.001 * speed;
    }

    this.gl.drawArrays(this.gl.POINTS, 0, this.starCount);
  }

  destroy() {
    // Cleanup resources if needed
  }
}
