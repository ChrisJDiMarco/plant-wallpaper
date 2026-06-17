/* Shell-fur rendering: procedural strand texture + a skinned ShaderMaterial
   per shell layer. Each shell extrudes the cat geometry along its skinned
   normals; an inertia uniform bends the tips opposite to body motion so the
   coat bounces and settles as the cat moves. */

const CatFur = (() => {
  const SHELL_COUNT = 16;

  // Random dot field; the red channel is strand presence. Higher values
  // survive to taller shells, so strands thin out naturally toward the tips.
  function makeStrandTexture(seedRandom) {
    const size = 512;
    const canvas = document.createElement('canvas');
    canvas.width = size;
    canvas.height = size;
    const ctx = canvas.getContext('2d');
    ctx.fillStyle = 'rgb(0,0,0)';
    ctx.fillRect(0, 0, size, size);
    const strandCount = 14000;
    for (let i = 0; i < strandCount; i++) {
      const value = Math.floor(70 + seedRandom() * 185);
      const radius = 0.6 + seedRandom() * 1.5;
      ctx.fillStyle = 'rgb(' + value + ',' + value + ',' + value + ')';
      ctx.beginPath();
      ctx.arc(seedRandom() * size, seedRandom() * size, radius, 0, Math.PI * 2);
      ctx.fill();
    }
    const texture = new THREE.CanvasTexture(canvas);
    texture.wrapS = THREE.RepeatWrapping;
    texture.wrapT = THREE.RepeatWrapping;
    return texture;
  }

  const VERTEX_SHADER = `
    attribute float aFur;
    attribute vec3 aColor;
    uniform float uShell;
    uniform float uFurLen;
    uniform vec3 uInertia;
    uniform float uTime;
    uniform vec2 uPetPos;
    uniform vec2 uPetDir;
    uniform float uPetAmp;
    varying vec3 vNormal;
    varying vec3 vColor;
    varying vec2 vUv;
    varying float vFur;
    varying vec3 vViewDir;
    #include <common>
    #include <skinning_pars_vertex>
    void main() {
      vUv = uv;
      vColor = aColor;
      vFur = aFur;
      vec3 objectNormal = vec3(normal);
      #include <skinbase_vertex>
      #include <skinnormal_vertex>
      vec3 transformed = vec3(position);
      #include <skinning_vertex>
      vec3 dir = normalize(objectNormal);
      float len = uFurLen * aFur * uShell;
      vec3 offset = dir * len;
      // Tip bend: gravity droop + inertia lag, quadratic along the strand so
      // roots stay anchored while tips swing. This is what makes it bouncy.
      float sag = uShell * uShell * aFur * uFurLen;
      offset += (vec3(0.0, -0.45, 0.0) + uInertia) * sag;
      // Faint breeze shimmer across the coat.
      offset.x += sin(uTime * 2.1 + position.y * 9.0 + position.x * 6.0) * 0.10 * sag;
      offset.z += cos(uTime * 1.7 + position.x * 7.0) * 0.06 * sag;
      // Petting: a localized rustle under the stroking hand. Skinned
      // positions are world-space here, so the falloff is a small disc
      // around the cursor — fur parts along the stroke and presses down,
      // springing back as the hand moves on.
      vec2 petDelta = transformed.xy - uPetPos;
      float petFall = exp(-dot(petDelta, petDelta) * 34.0) * uPetAmp;
      offset.x += uPetDir.x * petFall * sag * 4.5;
      offset.y -= (0.55 - uPetDir.y * 0.3) * petFall * sag * 2.6;
      offset.z += sin(uTime * 9.0 + position.x * 30.0) * petFall * sag * 0.8;
      transformed += offset;
      vec4 mvPosition = modelViewMatrix * vec4(transformed, 1.0);
      gl_Position = projectionMatrix * mvPosition;
      vNormal = normalize(normalMatrix * objectNormal);
      vViewDir = normalize(-mvPosition.xyz);
    }
  `;

  const FRAGMENT_SHADER = `
    precision highp float;
    uniform sampler2D uStrandTex;
    uniform float uShell;
    uniform float uDensity;
    uniform vec3 uLightDir;
    uniform vec3 uLightColor;
    uniform vec3 uAmbient;
    varying vec3 vNormal;
    varying vec3 vColor;
    varying vec2 vUv;
    varying float vFur;
    varying vec3 vViewDir;
    void main() {
      float alpha = 1.0;
      if (uShell > 0.001) {
        float strand = texture2D(uStrandTex, vUv * uDensity).r;
        alpha = smoothstep(uShell * 0.82, uShell * 0.82 + 0.22, strand);
        alpha *= 1.0 - uShell * uShell * 0.42;
        if (alpha < 0.03) discard;
      }
      vec3 N = normalize(vNormal);
      // Half-Lambert wrap keeps the shaded side soft like backlit fur.
      float diffuse = dot(N, normalize(uLightDir)) * 0.5 + 0.55;
      vec3 color = vColor * (uAmbient + uLightColor * diffuse);
      // Roots sit in shadow inside the coat; tips catch the light.
      color *= mix(0.58, 1.10, uShell);
      float rim = pow(1.0 - abs(dot(N, normalize(vViewDir))), 2.4);
      color += rim * vec3(1.0, 0.95, 0.82) * (0.10 + 0.42 * uShell);
      gl_FragColor = vec4(color, alpha);
    }
  `;

  function makeShellMaterials(strandTexture, lighting) {
    const materials = [];
    for (let i = 0; i <= SHELL_COUNT; i++) {
      const shell = i / SHELL_COUNT;
      const material = new THREE.ShaderMaterial({
        vertexShader: VERTEX_SHADER,
        fragmentShader: FRAGMENT_SHADER,
        transparent: i > 0,
        depthWrite: i === 0,
        uniforms: {
          uShell: { value: shell },
          uFurLen: { value: 0.085 },
          uInertia: { value: new THREE.Vector3() },
          uTime: { value: 0 },
          uStrandTex: { value: strandTexture },
          uDensity: { value: 5.0 },
          uPetPos: { value: new THREE.Vector2(0, -10) },
          uPetDir: { value: new THREE.Vector2(0, 0) },
          uPetAmp: { value: 0 },
          uLightDir: { value: lighting.direction },
          uLightColor: { value: lighting.color },
          uAmbient: { value: lighting.ambient }
        }
      });
      material.skinning = true;
      materials.push(material);
    }
    return materials;
  }

  // Shared per-frame uniform updates. inertia/time are the same object
  // references across all shells, so updating once updates everything.
  function makeUniformDriver(materials) {
    const inertia = new THREE.Vector3();
    const target = new THREE.Vector3();
    let petAmp = 0;
    return {
      // pet: { x, y, dir, amp } in world units — a stroking hand. The
      // shader parts the coat locally around (x, y); amp eases in and out
      // here so contact starting/ending never pops.
      update(dt, time, bodyVelocity, pet) {
        // Spring-damped lag: fur momentum trails the body's velocity.
        target.copy(bodyVelocity).multiplyScalar(-0.55);
        target.y = THREE.MathUtils.clamp(target.y, -0.9, 0.9);
        target.x = THREE.MathUtils.clamp(target.x, -0.9, 0.9);
        inertia.lerp(target, Math.min(1, dt * 7.5));
        const petTarget = pet ? THREE.MathUtils.clamp(pet.amp, 0, 1) : 0;
        petAmp += (petTarget - petAmp) * Math.min(1, dt * 10);
        for (const material of materials) {
          material.uniforms.uInertia.value.copy(inertia);
          material.uniforms.uTime.value = time;
          material.uniforms.uPetAmp.value = petAmp;
          if (pet) {
            material.uniforms.uPetPos.value.set(pet.x, pet.y);
            material.uniforms.uPetDir.value.set(
              THREE.MathUtils.clamp(pet.dir, -1, 1), 0
            );
          }
        }
      }
    };
  }

  return { SHELL_COUNT, makeStrandTexture, makeShellMaterials, makeUniformDriver };
})();
