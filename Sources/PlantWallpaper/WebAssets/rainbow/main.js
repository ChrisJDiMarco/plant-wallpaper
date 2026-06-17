(() => {
  const state = {
    active: false,
    targetPresence: 0,
    presence: 0,
    progress: 0,
    reduceMotion: false,
    running: false,
    lastTime: performance.now()
  };

  const renderer = new THREE.WebGLRenderer({
    alpha: true,
    antialias: true,
    premultipliedAlpha: false,
    powerPreference: 'low-power'
  });
  renderer.setClearColor(0x000000, 0);
  renderer.autoClear = true;
  document.body.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  const camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);

  const material = new THREE.ShaderMaterial({
    transparent: true,
    depthWrite: false,
    depthTest: false,
    blending: THREE.NormalBlending,
    uniforms: {
      uTime: { value: 0 },
      uPresence: { value: 0 },
      uProgress: { value: 0 },
      uAspect: { value: 1 },
      uReduceMotion: { value: 0 }
    },
    vertexShader: `
      varying vec2 vUv;
      void main() {
        vUv = uv;
        gl_Position = vec4(position.xy, 0.0, 1.0);
      }
    `,
    fragmentShader: `
      precision highp float;

      uniform float uTime;
      uniform float uPresence;
      uniform float uProgress;
      uniform float uAspect;
      uniform float uReduceMotion;
      varying vec2 vUv;

      float hash(vec2 p) {
        return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
      }

      float noise(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        vec2 u = f * f * (3.0 - 2.0 * f);
        return mix(
          mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
          mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
          u.y
        );
      }

      vec3 spectral(float t) {
        t = clamp(t, 0.0, 1.0);
        vec3 violet = vec3(0.36, 0.31, 0.88);
        vec3 blue = vec3(0.30, 0.55, 1.00);
        vec3 cyan = vec3(0.47, 0.86, 0.95);
        vec3 green = vec3(0.55, 0.84, 0.46);
        vec3 gold = vec3(1.00, 0.86, 0.42);
        vec3 rose = vec3(1.00, 0.43, 0.42);
        vec3 color = mix(violet, blue, smoothstep(0.00, 0.18, t));
        color = mix(color, cyan, smoothstep(0.16, 0.34, t));
        color = mix(color, green, smoothstep(0.30, 0.52, t));
        color = mix(color, gold, smoothstep(0.48, 0.73, t));
        color = mix(color, rose, smoothstep(0.70, 1.00, t));
        return color;
      }

      float arcWindow(float angle) {
        float left = smoothstep(0.10, 0.34, angle);
        float right = 1.0 - smoothstep(2.80, 3.06, angle);
        return left * right;
      }

      vec4 rainbowContribution(vec2 p, float radiusOffset, float alphaScale, float reverseColor) {
        vec2 center = vec2(0.50, -0.22);
        vec2 axis = vec2(0.76, 0.96);
        vec2 q = vec2((p.x - center.x) / axis.x, (p.y - center.y) / axis.y);
        float radius = length(q);
        float angle = atan(q.y, q.x);
        float arc = arcWindow(angle);

        float targetRadius = 1.0 + radiusOffset;
        float distance = abs(radius - targetRadius);
        float width = 0.104;
        float core = exp(-pow(distance / width, 2.0) * 2.1);
        float halo = exp(-pow(distance / 0.245, 2.0)) * 0.16;

        float band = clamp((radius - (targetRadius - width)) / (width * 2.0), 0.0, 1.0);
        band = mix(band, 1.0 - band, reverseColor);
        vec3 color = spectral(band);

        float lowFade = smoothstep(0.035, 0.18, p.y);
        float highFade = 1.0 - smoothstep(0.84, 1.03, p.y);
        float atmosphere = lowFade * highFade;
        float edgeMist = smoothstep(0.0, 0.34, angle) * (1.0 - smoothstep(2.74, 3.12, angle));
        float shimmer = mix(
          0.94 + noise(p * 7.0 + uTime * 0.035) * 0.08,
          1.0,
          step(0.5, uReduceMotion)
        );

        float alpha = (core * 0.145 + halo * 0.06) * arc * atmosphere * edgeMist * alphaScale * shimmer;
        vec3 mist = vec3(0.88, 0.94, 1.0) * halo * arc * atmosphere * 0.028 * alphaScale;
        return vec4(color * alpha + mist, alpha);
      }

      void main() {
        vec2 p = vUv;
        float breathing = mix(
          0.96 + sin(uTime * 0.34 + uProgress * 2.4) * 0.04,
          1.0,
          step(0.5, uReduceMotion)
        );
        float presence = clamp(uPresence * breathing, 0.0, 1.0);
        if (presence <= 0.001) discard;

        vec4 primary = rainbowContribution(p, 0.0, presence, 0.0);
        vec4 secondary = rainbowContribution(p + vec2(0.012, -0.018), 0.205, presence * 0.23, 1.0);

        vec3 color = primary.rgb + secondary.rgb;
        float alpha = primary.a + secondary.a * 0.55;

        float veil = exp(-pow(abs(p.y - 0.46) / 0.55, 2.0))
          * smoothstep(0.0, 0.20, p.x)
          * (1.0 - smoothstep(0.82, 1.0, p.x))
          * 0.022
          * presence;
        color += vec3(0.78, 0.88, 1.0) * veil;
        alpha += veil * 0.34;

        if (alpha <= 0.001) discard;
        gl_FragColor = vec4(color, clamp(alpha, 0.0, 0.22));
      }
    `
  });

  const plane = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), material);
  scene.add(plane);

  function easedPresence(progress) {
    const fadeWindow = 0.12;
    const fadeIn = Math.min(1, progress / fadeWindow);
    const fadeOut = Math.min(1, (1 - progress) / fadeWindow);
    return Math.max(0, Math.min(fadeIn, fadeOut));
  }

  function resize() {
    const width = Math.max(1, window.innerWidth);
    const height = Math.max(1, window.innerHeight);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.5));
    renderer.setSize(width, height, false);
    material.uniforms.uAspect.value = width / height;
  }

  function animate(now) {
    const dt = Math.min(0.08, Math.max(0.001, (now - state.lastTime) / 1000));
    state.lastTime = now;
    const easing = state.targetPresence > state.presence ? 4.8 : 2.7;
    state.presence += (state.targetPresence - state.presence) * Math.min(1, dt * easing);

    material.uniforms.uTime.value = now / 1000;
    material.uniforms.uPresence.value = state.presence;
    material.uniforms.uProgress.value = state.progress;
    material.uniforms.uReduceMotion.value = state.reduceMotion ? 1 : 0;

    renderer.render(scene, camera);

    if (state.active || state.presence > 0.002) {
      requestAnimationFrame(animate);
      return;
    }
    state.running = false;
  }

  function ensureLoop() {
    if (state.running) return;
    state.running = true;
    state.lastTime = performance.now();
    requestAnimationFrame(animate);
  }

  window.rainbowBridge = {
    configure(payload = {}) {
      state.active = !!payload.active;
      state.progress = Number.isFinite(payload.progress) ? Math.max(0, Math.min(1, payload.progress)) : 0;
      state.reduceMotion = !!payload.reduceMotion;
      state.targetPresence = state.active ? easedPresence(state.progress) : 0;
      ensureLoop();
    },
    status() {
      return {
        active: state.active,
        progress: state.progress,
        presence: state.presence,
        reduceMotion: state.reduceMotion
      };
    }
  };

  window.addEventListener('resize', resize);
  resize();
  renderer.render(scene, camera);
})();
