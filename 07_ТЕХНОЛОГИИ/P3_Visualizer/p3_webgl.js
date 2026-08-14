/**
 * DYNAMIS v3.0 — WebGL P³ Renderer
 * ==================================
 * GLSL шейдеры для рендеринга тысяч точек/мировых линий/рельефа на P³.
 * 
 * Заменяет Canvas2D для режимов с большим количеством геометрии.
 * Canvas2D сохранён для простых 2D-режимов (режимы 0-7).
 * WebGL используется для режимов 8 (Spacetime), 9 (DEM), 10+ (Designer).
 */

// ═══════════════════════════════════════════
// GLSL SHADERS
// ═══════════════════════════════════════════

const P3_VERT = `
precision highp float;

// P³ vertex: homogeneous coordinates [X:Y:Z:W]
attribute vec4 aHomVec;    // (X, Y, Z, W) — point in P³
attribute vec3 aColor;     // RGB color
attribute float aSize;     // Point size
attribute float aCardId;   // Affine card: 0=UW, 1=UX, 2=UY, 3=UZ

// Uniforms
uniform mat4 uPGL4;        // PGL(4,R) transform
uniform mat4 uProjection;  // Perspective projection
uniform mat4 uView;        // View matrix (camera)
uniform float uWThreshold; // W-калибровка: точки с |W| < threshold → невидимы
uniform float uTime;       // Время для анимации

varying vec3 vColor;
varying float vW;
varying float vCardId;
varying float vDFS;        // d_FS от наблюдателя (0,0,0,1)

void main() {
  // Apply PGL(4,R) transform
  vec4 transformed = uPGL4 * aHomVec;
  
  // Normalize on S³
  float norm = length(transformed);
  if (norm < 1e-15) {
    // Zero vector — skip
    gl_Position = vec4(0.0, 0.0, -2.0, 1.0);
    gl_PointSize = 0.0;
    return;
  }
  vec4 p = transformed / norm;
  
  // W-калибровка: объекты с W→0 исчезают (горизонт событий)
  float W = p.w;
  vW = W;
  
  // Fubini-Study distance from observer (0,0,0,1)
  // d_FS = arccos(|<p, obs>|) = arccos(|W|)
  float cosAngle = abs(W);
  vDFS = acos(clamp(cosAngle, 0.0, 1.0));
  
  // Pick affine card for projection
  // UW (W≠0): (x,y,z) = (X/W, Y/W, Z/W) → standard 3D
  // UX (X≠0): (y,z,w) = (Y/X, Z/X, W/X) → mirrored
  vec3 pos3d;
  float absX = abs(p.x), absY = abs(p.y), absZ = abs(p.z), absW = abs(p.w);
  
  if (absW >= absX && absW >= absY && absW >= absZ) {
    // UW card: standard projection
    pos3d = vec3(p.x / p.w, p.y / p.w, p.z / p.w);
    vCardId = 0.0;
  } else if (absX >= absY && absX >= absZ) {
    // UX card: X≠0
    pos3d = vec3(p.y / p.x, p.z / p.x, p.w / p.x);
    vCardId = 1.0;
  } else if (absY >= absZ) {
    // UY card: Y≠0
    pos3d = vec3(p.x / p.y, p.z / p.y, p.w / p.y);
    vCardId = 2.0;
  } else {
    // UZ card: Z≠0
    pos3d = vec3(p.x / p.z, p.y / p.z, p.w / p.z);
    vCardId = 3.0;
  }
  
  // Apply view and projection
  vec4 viewPos = uView * vec4(pos3d, 1.0);
  gl_Position = uProjection * viewPos;
  
  // Point size: larger when |W| is large (visible), smaller near horizon
  float visibility = smoothstep(uWThreshold, uWThreshold + 0.1, abs(W));
  gl_PointSize = aSize * visibility * (1.0 + abs(W));
  
  // Color with card tinting
  vec3 cardTint = vec3(1.0);
  if (vCardId < 0.5) cardTint = vec3(0.47, 0.67, 1.0);      // UW = blue
  else if (vCardId < 1.5) cardTint = vec3(0.47, 1.0, 0.47);  // UX = green
  else if (vCardId < 2.5) cardTint = vec3(1.0, 0.67, 0.47);  // UY = orange
  else cardTint = vec3(1.0, 0.47, 1.0);                       // UZ = purple
  
  vColor = aColor * cardTint * visibility;
}
;

const P3_FRAG = `
precision highp float;

varying vec3 vColor;
varying float vW;
varying float vCardId;
varying float vDFS;

uniform float uTime;

void main() {
  // Circular point shape (not square)
  vec2 coord = gl_PointCoord - vec2(0.5);
  float dist = length(coord);
  if (dist > 0.5) discard;
  
  // Glow effect: brighter at center
  float glow = exp(-dist * 4.0);
  
  // W-based alpha: fade near horizon
  float alpha = smoothstep(0.0, 0.1, abs(vW));
  
  // Z/2Z pulse: antipodal points flicker at 18.7 Hz
  float pulse = 0.85 + 0.15 * sin(uTime * 18.7 * 6.28318);
  
  gl_FragColor = vec4(vColor * glow * pulse, alpha * glow);
}
`;

// Line shader — connects worldline events
const LINE_VERT = `
precision highp float;

attribute vec3 aPos;       // Already projected 3D position
attribute vec3 aColor;
attribute float aAlpha;

uniform mat4 uProjection;
uniform mat4 uView;

varying vec3 vColor;
varying float vAlpha;

void main() {
  vec4 viewPos = uView * vec4(aPos, 1.0);
  gl_Position = uProjection * viewPos;
  vColor = aColor;
  vAlpha = aAlpha;
}
`;

const LINE_FRAG = `
precision highp float;
varying vec3 vColor;
varying float vAlpha;
void main() {
  gl_FragColor = vec4(vColor, vAlpha);
}
`;


// ═══════════════════════════════════════════
// WEBGL P³ RENDERER CLASS
// ═══════════════════════════════════════════

class P3WebGLRenderer {
  constructor(canvas) {
    this.canvas = canvas;
    this.gl = canvas.getContext('webgl', {
      alpha: true,
      antialias: true,
      depth: true,
      blend: true,
      premultipliedAlpha: false
    });
    
    if (!this.gl) {
      console.error('WebGL не поддерживается');
      return;
    }
    
    this.pointProgram = null;
    this.lineProgram = null;
    this.pointCount = 0;
    this.lineCount = 0;
    
    // Matrices
    this.pgl4 = this._mat4Identity();
    this.projection = this._mat4Identity();
    this.view = this._mat4Identity();
    
    // State
    this.wThreshold = 0.02;
    this.time = 0;
    this.cameraTheta = 0.3;
    this.cameraPhi = 0.5;
    this.cameraDist = 3.0;
    this.dragStart = null;
    
    this._initShaders();
    this._initBuffers();
    this._initBlend();
    this._initMouse();
  }
  
  _mat4Identity() {
    return new Float32Array([1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1]);
  }
  
  _initShaders() {
    const gl = this.gl;
    this.pointProgram = this._createProgram(P3_VERT, P3_FRAG);
    this.lineProgram = this._createProgram(LINE_VERT, LINE_FRAG);
  }
  
  _createProgram(vertSrc, fragSrc) {
    const gl = this.gl;
    const vs = gl.createShader(gl.VERTEX_SHADER);
    gl.shaderSource(vs, vertSrc);
    gl.compileShader(vs);
    if (!gl.getShaderParameter(vs, gl.COMPILE_STATUS)) {
      console.error('VS:', gl.getShaderInfoLog(vs));
      return null;
    }
    
    const fs = gl.createShader(gl.FRAGMENT_SHADER);
    gl.shaderSource(fs, fragSrc);
    gl.compileShader(fs);
    if (!gl.getShaderParameter(fs, gl.COMPILE_STATUS)) {
      console.error('FS:', gl.getShaderInfoLog(fs));
      return null;
    }
    
    const prog = gl.createProgram();
    gl.attachShader(prog, vs);
    gl.attachShader(prog, fs);
    gl.linkProgram(prog);
    
    if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) {
      console.error('Link:', gl.getProgramInfoLog(prog));
      return null;
    }
    
    return prog;
  }
  
  _initBuffers() {
    const gl = this.gl;
    // Point buffers (interleaved: X,Y,Z,W, R,G,B, size, cardId)
    this.pointBuffer = gl.createBuffer();
    // Line buffers (interleaved: x,y,z, R,G,B, alpha)
    this.lineBuffer = gl.createBuffer();
  }
  
  _initBlend() {
    const gl = this.gl;
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    gl.enable(gl.DEPTH_TEST);
    gl.depthFunc(gl.LEQUAL);
  }
  
  _initMouse() {
    const c = this.canvas;
    c.addEventListener('mousedown', e => {
      this.dragStart = { x: e.clientX, y: e.clientY, theta: this.cameraTheta, phi: this.cameraPhi };
    });
    c.addEventListener('mousemove', e => {
      if (!this.dragStart) return;
      const dx = e.clientX - this.dragStart.x;
      const dy = e.clientY - this.dragStart.y;
      this.cameraPhi = this.dragStart.phi + dx * 0.005;
      this.cameraTheta = Math.max(-Math.PI/2 + 0.01, Math.min(Math.PI/2 - 0.01, this.dragStart.theta + dy * 0.005));
    });
    c.addEventListener('mouseup', () => { this.dragStart = null; });
    c.addEventListener('wheel', e => {
      this.cameraDist *= (1 + e.deltaY * 0.001);
      this.cameraDist = Math.max(0.5, Math.min(20, this.cameraDist));
      e.preventDefault();
    }, { passive: false });
  }
  
  // ─── Upload P³ points ───
  // points: [{X, Y, Z, W, r, g, b, size, card}, ...]
  uploadPoints(points) {
    const gl = this.gl;
    // Interleaved: X,Y,Z,W, R,G,B, size, cardId = 10 floats per point
    const data = new Float32Array(points.length * 10);
    for (let i = 0; i < points.length; i++) {
      const p = points[i];
      const off = i * 10;
      data[off]   = p.X || 0; data[off+1] = p.Y || 0;
      data[off+2] = p.Z || 0; data[off+3] = p.W || 1;
      data[off+4] = p.r || 0.5; data[off+5] = p.g || 0.5; data[off+6] = p.b || 0.5;
      data[off+7] = p.size || 3.0;
      data[off+8] = p.card || 0;
      data[off+9] = 0; // padding
    }
    gl.bindBuffer(gl.ARRAY_BUFFER, this.pointBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, data, gl.DYNAMIC_DRAW);
    this.pointCount = points.length;
  }
  
  // ─── Upload line segments ───
  // lines: [{x1,y1,z1, x2,y2,z2, r,g,b, alpha}, ...]
  uploadLines(lines) {
    const gl = this.gl;
    // 2 vertices per line: x,y,z, R,G,B, alpha = 7 floats × 2
    const data = new Float32Array(lines.length * 14);
    for (let i = 0; i < lines.length; i++) {
      const l = lines[i];
      const off = i * 14;
      data[off]   = l.x1; data[off+1] = l.y1; data[off+2] = l.z1;
      data[off+3] = l.r||0.5; data[off+4] = l.g||0.5; data[off+5] = l.b||0.5;
      data[off+6] = l.alpha||0.5;
      data[off+7] = l.x2; data[off+8] = l.y2; data[off+9] = l.z2;
      data[off+10]= l.r||0.5; data[off+11]= l.g||0.5; data[off+12]= l.b||0.5;
      data[off+13]= l.alpha||0.5;
    }
    gl.bindBuffer(gl.ARRAY_BUFFER, this.lineBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, data, gl.DYNAMIC_DRAW);
    this.lineCount = lines.length;
  }
  
  // ─── Render frame ───
  render(time) {
    const gl = this.gl;
    this.time = time;
    
    // Resize
    const dpr = window.devicePixelRatio || 1;
    const w = this.canvas.clientWidth * dpr;
    const h = this.canvas.clientHeight * dpr;
    if (this.canvas.width !== w || this.canvas.height !== h) {
      this.canvas.width = w;
      this.canvas.height = h;
    }
    gl.viewport(0, 0, w, h);
    
    // Clear
    gl.clearColor(0.031, 0.031, 0.047, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    
    // Update matrices
    this._updateMatrices(w, h);
    
    // Draw lines first (behind points)
    this._drawLines();
    
    // Draw points
    this._drawPoints();
  }
  
  _updateMatrices(w, h) {
    const aspect = w / h;
    const near = 0.01, far = 100;
    const fov = Math.PI / 4;
    
    // Perspective
    const f = 1 / Math.tan(fov / 2);
    this.projection = new Float32Array([
      f/aspect, 0, 0, 0,
      0, f, 0, 0,
      0, 0, (far+near)/(near-far), -1,
      0, 0, 2*far*near/(near-far), 0
    ]);
    
    // View (orbit camera)
    const ct = Math.cos(this.cameraTheta), st = Math.sin(this.cameraTheta);
    const cp = Math.cos(this.cameraPhi), sp = Math.sin(this.cameraPhi);
    const d = this.cameraDist;
    const eye = [d*ct*cp, d*st, d*ct*sp];
    const target = [0, 0, 0];
    const up = [0, 1, 0];
    
    // LookAt
    const zx = eye[0]-target[0], zy = eye[1]-target[1], zz = eye[2]-target[2];
    let zn = Math.sqrt(zx*zx+zy*zy+zz*zz);
    const fz = [zx/zn, zy/zn, zz/zn];
    const xx = up[1]*fz[2]-up[2]*fz[1], xy = up[2]*fz[0]-up[0]*fz[2], xz = up[0]*fz[1]-up[1]*fz[0];
    let xn = Math.sqrt(xx*xx+xy*xy+xz*xz);
    const fx = [xx/xn, xy/xn, xz/xn];
    const fy = [fz[1]*fx[2]-fz[2]*fx[1], fz[2]*fx[0]-fz[0]*fx[2], fz[0]*fx[1]-fz[1]*fx[0]];
    
    this.view = new Float32Array([
      fx[0], fy[0], fz[0], 0,
      fx[1], fy[1], fz[1], 0,
      fx[2], fy[2], fz[2], 0,
      -(fx[0]*eye[0]+fx[1]*eye[1]+fx[2]*eye[2]),
      -(fy[0]*eye[0]+fy[1]*eye[1]+fy[2]*eye[2]),
      -(fz[0]*eye[0]+fz[1]*eye[1]+fz[2]*eye[2]),
      1
    ]);
  }
  
  _drawPoints() {
    if (this.pointCount === 0 || !this.pointProgram) return;
    const gl = this.gl;
    const prog = this.pointProgram;
    
    gl.useProgram(prog);
    gl.bindBuffer(gl.ARRAY_BUFFER, this.pointBuffer);
    
    // Attributes (stride = 10 floats = 40 bytes)
    const stride = 40;
    const aHomVec = gl.getAttribLocation(prog, 'aHomVec');
    gl.enableVertexAttribArray(aHomVec);
    gl.vertexAttribPointer(aHomVec, 4, gl.FLOAT, false, stride, 0);
    
    const aColor = gl.getAttribLocation(prog, 'aColor');
    gl.enableVertexAttribArray(aColor);
    gl.vertexAttribPointer(aColor, 3, gl.FLOAT, false, stride, 16);
    
    const aSize = gl.getAttribLocation(prog, 'aSize');
    gl.enableVertexAttribArray(aSize);
    gl.vertexAttribPointer(aSize, 1, gl.FLOAT, false, stride, 28);
    
    const aCardId = gl.getAttribLocation(prog, 'aCardId');
    gl.enableVertexAttribArray(aCardId);
    gl.vertexAttribPointer(aCardId, 1, gl.FLOAT, false, stride, 32);
    
    // Uniforms
    gl.uniformMatrix4fv(gl.getUniformLocation(prog, 'uPGL4'), false, this.pgl4);
    gl.uniformMatrix4fv(gl.getUniformLocation(prog, 'uProjection'), false, this.projection);
    gl.uniformMatrix4fv(gl.getUniformLocation(prog, 'uView'), false, this.view);
    gl.uniform1f(gl.getUniformLocation(prog, 'uWThreshold'), this.wThreshold);
    gl.uniform1f(gl.getUniformLocation(prog, 'uTime'), this.time);
    
    gl.drawArrays(gl.POINTS, 0, this.pointCount);
  }
  
  _drawLines() {
    if (this.lineCount === 0 || !this.lineProgram) return;
    const gl = this.gl;
    const prog = this.lineProgram;
    
    gl.useProgram(prog);
    gl.bindBuffer(gl.ARRAY_BUFFER, this.lineBuffer);
    
    const stride = 28; // 7 floats × 4 bytes
    const aPos = gl.getAttribLocation(prog, 'aPos');
    gl.enableVertexAttribArray(aPos);
    gl.vertexAttribPointer(aPos, 3, gl.FLOAT, false, stride, 0);
    
    const aColor = gl.getAttribLocation(prog, 'aColor');
    gl.enableVertexAttribArray(aColor);
    gl.vertexAttribPointer(aColor, 3, gl.FLOAT, false, stride, 12);
    
    const aAlpha = gl.getAttribLocation(prog, 'aAlpha');
    gl.enableVertexAttribArray(aAlpha);
    gl.vertexAttribPointer(aAlpha, 1, gl.FLOAT, false, stride, 24);
    
    gl.uniformMatrix4fv(gl.getUniformLocation(prog, 'uProjection'), false, this.projection);
    gl.uniformMatrix4fv(gl.getUniformLocation(prog, 'uView'), false, this.view);
    
    gl.drawArrays(gl.LINES, 0, this.lineCount * 2);
  }
  
  // ─── Generate terrain point cloud ───
  generateTerrain(nLat = 90, nLon = 180, style = 'earth') {
    const points = [];
    const lines = [];
    
    for (let i = 0; i < nLat; i++) {
      const lat = 90 - i * 180 / nLat;
      const latR = lat * Math.PI / 180;
      
      for (let j = 0; j < nLon; j++) {
        const lon = -180 + j * 360 / nLon;
        const lonR = lon * Math.PI / 180;
        
        // Synthetic elevation
        let h = 0;
        if (style === 'earth') {
          for (let o = 0; o < 5; o++) {
            const f = 2 ** o, a = 600 / f;
            h += a * Math.sin(f * latR * 1.3 + o) * Math.cos(f * lonR + o * 0.7);
          }
          h += 2000 * Math.exp(-((lat-28)**2/200 + (lon-85)**2/500));
          h += 1500 * Math.exp(-((lat+15)**2/300 + (lon+70)**2/200));
        } else if (style === 'etheria') {
          const K = 9/7;
          for (let o = 0; o < 5; o++) {
            const f = 2 ** o, a = 500 / f * K;
            h += a * Math.sin(f * latR * K) * Math.cos(f * lonR + o);
          }
          h -= 3000 * Math.exp(-((lat+60)**2/200));
          h += 1500 * Math.exp(-((lat-50)**2/100 + (lon-35)**2/200));
        }
        
        // Sphere point
        const r = 1 + h / 8000;
        const X = r * Math.cos(latR) * Math.cos(lonR);
        const Y = r * Math.cos(latR) * Math.sin(lonR);
        const Z = r * Math.sin(latR);
        const W = 1 / Math.sqrt(X*X + Y*Y + Z*Z + 1);
        
        // Color by elevation
        const t = (h + 5000) / 10000;
        const r_c = t < 0.4 ? 0.1 : t < 0.6 ? 0.2 + (t-0.4)*3 : 0.8;
        const g_c = t < 0.4 ? 0.2 + t*1.5 : t < 0.6 ? 0.8 : 0.8 - (t-0.6)*2;
        const b_c = t < 0.4 ? 0.6 - t : 0.1;
        
        points.push({ X, Y, Z, W, r: r_c, g: g_c, b: b_c, size: 2.5, card: 0 });
        
        // Connect to neighbors (grid lines)
        if (j > 0 && i % 2 === 0) {
          const prev = points[points.length - 2];
          lines.push({
            x1: X/Math.sqrt(X*X+Y*Y+Z*Z+W*W), y1: Y/Math.sqrt(X*X+Y*Y+Z*Z+W*W),
            z1: Z/Math.sqrt(X*X+Y*Y+Z*Z+W*W),
            x2: prev.X, y2: prev.Y, z2: prev.Z,
            r: r_c*0.3, g: g_c*0.3, b: b_c*0.3, alpha: 0.15
          });
        }
      }
    }
    
    return { points, lines };
  }
  
  // ─── Generate worldlines ───
  generateWorldlines(nodes, trailLen = 40, time = 0) {
    const points = [];
    const lines = [];
    
    nodes.forEach(node => {
      const norm = Math.sqrt(node.X**2 + node.Y**2 + node.Z**2 + node.W**2);
      const x0 = node.X/norm, y0 = node.Y/norm, z0 = node.Z/norm, w0 = node.W/norm;
      
      let prevProj = null;
      for (let step = 0; step < trailLen; step++) {
        const t = time - (trailLen - step) * 0.005;
        const angle = 0.01 * Math.sin(2 * Math.PI * 18.7 * t);
        const c = Math.cos(angle), s = Math.sin(angle);
        const x_new = c * x0 + s * w0;
        const w_new = -s * x0 + c * w0;
        const n2 = Math.sqrt(x_new**2 + y0**2 + z0**2 + w_new**2);
        
        const X = x_new/n2, Y = y0/n2, Z = z0/n2, W = w_new/n2;
        
        points.push({
          X, Y, Z, W,
          r: node.r || 0.47, g: node.g || 0.67, b: node.b || 1.0,
          size: 1.5 + Math.abs(W) * 2, card: 0
        });
        
        // Project to 3D for line
        const proj = { x: X, y: Z, z: Y }; // simple orthographic
        if (prevProj) {
          const alpha = 0.1 + 0.4 * (step / trailLen);
          lines.push({
            x1: prevProj.x, y1: prevProj.y, z1: prevProj.z,
            x2: proj.x, y2: proj.y, z2: proj.z,
            r: node.r||0.47, g: node.g||0.67, b: node.b||1.0, alpha
          });
        }
        prevProj = proj;
      }
    });
    
    return { points, lines };
  }
}

// Export for use in extensions.js and designer
window.P3WebGLRenderer = P3WebGLRenderer;
