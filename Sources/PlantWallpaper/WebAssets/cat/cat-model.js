/* Builds the cat: a procedural skinned mesh (blob-sculpted, fur hides the
   seams), a bone skeleton driven by cat-anim.js, shell-fur layers, and the
   non-skinned face details (eyes, nose, whiskers, inner ears) parented to
   the head bone. All rest-pose coordinates are world space, cat facing +x,
   ground at y=0. Shoulder height is ~0.6 world units. */

const CatModel = (() => {
  const PALETTES = {
    orange: {
      base: 0xe08538, stripe: 0x9d551e, belly: 0xf6e7c9,
      sock: 0xf7f1e4, muzzle: 0xf7f1e4, nose: 0xd97f74,
      iris: '#d99a2b', irisEdge: '#8a5a14'
    },
    gray: {
      base: 0x8d8d96, stripe: 0x595964, belly: 0xe8e6e0,
      sock: 0xefece5, muzzle: 0xeceae3, nose: 0xb98b8b,
      iris: '#a8b85a', irisEdge: '#5d6b2a'
    },
    charcoal: {
      base: 0x46424a, stripe: 0x2e2b32, belly: 0x787176,
      sock: 0x615b60, muzzle: 0x6e6870, nose: 0x8a6a6a,
      iris: '#e3b341', irisEdge: '#8a651c'
    },
    cream: {
      base: 0xe8d7b8, stripe: 0xc4aa80, belly: 0xf7efe0,
      sock: 0xfaf6ec, muzzle: 0xfaf6ec, nose: 0xdf9b90,
      iris: '#7fa8c9', irisEdge: '#3d6485'
    },
    black: {
      pattern: 'solid',
      base: 0x232127, stripe: 0x18161c, belly: 0x312e36,
      sock: 0x232127, muzzle: 0x37343d, nose: 0x4d4a52,
      iris: '#e0b94d', irisEdge: '#8a6a1e'
    },
    white: {
      pattern: 'solid',
      base: 0xf2ede2, stripe: 0xe2dccd, belly: 0xfaf7ef,
      sock: 0xfaf7ef, muzzle: 0xfaf7ef, nose: 0xe3a49a,
      iris: '#86b9dd', irisEdge: '#46758f'
    },
    siamese: {
      pattern: 'pointed',
      base: 0xe9dcc4, stripe: 0x52392a, belly: 0xf4ecdc,
      sock: 0x52392a, muzzle: 0x5d4434, nose: 0x3f2c20,
      iris: '#6f9fd8', irisEdge: '#33567e'
    },
    tuxedo: {
      pattern: 'tuxedo',
      base: 0x26242b, stripe: 0x18161c, belly: 0xf5f1e8,
      sock: 0xf5f1e8, muzzle: 0xf5f1e8, nose: 0x3f3c44,
      iris: '#d2a93e', irisEdge: '#7d621c'
    },
    calico: {
      pattern: 'calico',
      base: 0xf3eee3, stripe: 0xd6873c, belly: 0xfaf6ee,
      sock: 0xfaf6ee, muzzle: 0xfaf6ee, nose: 0xdf9b90,
      patch: 0x2d2a31,
      iris: '#bb953f', irisEdge: '#6f5618'
    },
    silver: {
      // Silver tabby: pale ghost-grey coat, charcoal mackerel striping, green eyes.
      base: 0xc9cdd2, stripe: 0x4a4e57, belly: 0xeef0f2,
      sock: 0xf2f4f6, muzzle: 0xeef0f2, nose: 0xc98f8f,
      iris: '#9ab85a', irisEdge: '#566b2a'
    },
    brown: {
      // Brown classic tabby: warm sable coat, dark chocolate striping, amber eyes.
      base: 0x8a5a32, stripe: 0x3e271a, belly: 0xd8c2a4,
      sock: 0xe7d6bb, muzzle: 0xe2cdb0, nose: 0x6b4636,
      iris: '#d99a2b', irisEdge: '#8a5a14'
    },
    redtabby: {
      // Deep red/flame tabby: richer, rustier ginger than the orange variant.
      base: 0xcf6a2a, stripe: 0x8a3f16, belly: 0xf0d8b8,
      sock: 0xf5ead6, muzzle: 0xf2e4cc, nose: 0xd97f74,
      iris: '#e0a93e', irisEdge: '#8a651c'
    },
    blue: {
      // Solid blue/grey (Russian-blue-ish): cool slate coat, copper-gold eyes.
      pattern: 'solid',
      base: 0x7c8893, stripe: 0x5a646e, belly: 0xaeb6bd,
      sock: 0x7c8893, muzzle: 0x8a949d, nose: 0x9a8a8f,
      iris: '#caa94a', irisEdge: '#7d6220'
    },
    bluepoint: {
      // Blue-point Siamese: cool cream body with slate-blue points, blue eyes.
      pattern: 'pointed',
      base: 0xece4d6, stripe: 0x6a727c, belly: 0xf3ecdf,
      sock: 0x6a727c, muzzle: 0x767e88, nose: 0x55585f,
      iris: '#6f9fd8', irisEdge: '#33567e'
    }
  };

  const FACE_DETAIL_SPEC = {
    eyeTextureSize: 192,
    whiskersPerSide: 5,
    whiskerLengthVariance: true,
    whiskerRoots: true,
    cheekPads: true,
    eyelidRims: true,
    noseBridge: true,
    mouthLine: true,
    realisticTongue: true,
    groomingTargets: ['paw', 'face', 'flank', 'belly', 'tail', 'haunch']
  };

  function v3(x, y, z) { return new THREE.Vector3(x, y, z); }

  // [name, parentName, restWorldX, restWorldY, restWorldZ]
  function boneDefinitions() {
    const defs = [
      ['root', null, 0, 0.46, 0],
      ['hips', 'root', -0.30, 0.47, 0],
      ['spine', 'root', -0.02, 0.49, 0],
      ['chest', 'spine', 0.26, 0.48, 0],
      ['neck', 'chest', 0.40, 0.53, 0],
      ['head', 'neck', 0.51, 0.64, 0]
    ];
    let tailX = -0.44;
    let tailY = 0.50;
    for (let i = 1; i <= 6; i++) {
      defs.push(['tail' + i, i === 1 ? 'hips' : 'tail' + (i - 1), tailX, tailY, 0]);
      tailX -= 0.105;
      tailY -= 0.008;
    }
    for (const side of [['L', 0.13], ['R', -0.13]]) {
      const [s, z] = side;
      defs.push(['thighB' + s, 'hips', -0.28, 0.42, z]);
      defs.push(['shinB' + s, 'thighB' + s, -0.28, 0.23, z]);
      defs.push(['footB' + s, 'shinB' + s, -0.28, 0.055, z]);
    }
    for (const side of [['L', 0.115], ['R', -0.115]]) {
      const [s, z] = side;
      defs.push(['shoulderF' + s, 'chest', 0.30, 0.44, z]);
      defs.push(['elbowF' + s, 'shoulderF' + s, 0.30, 0.235, z]);
      defs.push(['footF' + s, 'elbowF' + s, 0.30, 0.05, z]);
    }
    return defs;
  }

  function buildSkeleton() {
    const byName = {};
    const rest = {};
    const list = [];
    const indexByName = {};
    for (const [name, parent, x, y, z] of boneDefinitions()) {
      const bone = new THREE.Bone();
      bone.name = name;
      const world = v3(x, y, z);
      rest[name] = world.clone();
      if (parent) {
        byName[parent].add(bone);
        bone.position.copy(world).sub(rest[parent]);
      } else {
        bone.position.copy(world);
      }
      indexByName[name] = list.length;
      byName[name] = bone;
      list.push(bone);
    }
    return { list, byName, rest, indexByName };
  }

  // Accumulates transformed part geometries into one skinned BufferGeometry.
  class GeometryAccumulator {
    constructor(indexByName) {
      this.indexByName = indexByName;
      this.positions = [];
      this.normals = [];
      this.uvs = [];
      this.colors = [];
      this.fur = [];
      this.skinIndices = [];
      this.skinWeights = [];
      this.indices = [];
      this.color = new THREE.Color();
    }

    add(geometry, opts) {
      const posAttr = geometry.attributes.position;
      const normAttr = geometry.attributes.normal;
      const uvAttr = geometry.attributes.uv;
      const base = this.positions.length / 3;
      const p = new THREE.Vector3();
      for (let i = 0; i < posAttr.count; i++) {
        p.fromBufferAttribute(posAttr, i);
        this.positions.push(p.x, p.y, p.z);
        this.normals.push(normAttr.getX(i), normAttr.getY(i), normAttr.getZ(i));
        this.uvs.push(uvAttr.getX(i), uvAttr.getY(i));
        const colorValue = opts.colorFn ? opts.colorFn(p) : opts.color;
        this.color.set(colorValue);
        this.colors.push(this.color.r, this.color.g, this.color.b);
        this.fur.push(opts.furFn ? opts.furFn(p) : opts.fur);
        const weights = opts.weightFn(p);
        let total = 0;
        for (const [, w] of weights) total += w;
        for (let s = 0; s < 4; s++) {
          if (s < weights.length) {
            const boneIndex = this.indexByName[weights[s][0]];
            if (boneIndex === undefined) {
              // A typo here silently rebinds vertices to the root bone —
              // fail loudly instead.
              throw new Error('Unknown bone in skin weights: ' + weights[s][0]);
            }
            this.skinIndices.push(boneIndex);
            this.skinWeights.push(weights[s][1] / total);
          } else {
            this.skinIndices.push(0);
            this.skinWeights.push(0);
          }
        }
      }
      const index = geometry.index;
      for (let i = 0; i < index.count; i++) {
        this.indices.push(base + index.getX(i));
      }
      geometry.dispose();
    }

    build() {
      const geometry = new THREE.BufferGeometry();
      geometry.setAttribute('position', new THREE.Float32BufferAttribute(this.positions, 3));
      geometry.setAttribute('normal', new THREE.Float32BufferAttribute(this.normals, 3));
      geometry.setAttribute('uv', new THREE.Float32BufferAttribute(this.uvs, 2));
      geometry.setAttribute('aColor', new THREE.Float32BufferAttribute(this.colors, 3));
      geometry.setAttribute('aFur', new THREE.Float32BufferAttribute(this.fur, 1));
      geometry.setAttribute('skinIndex', new THREE.Uint16BufferAttribute(this.skinIndices, 4));
      geometry.setAttribute('skinWeight', new THREE.Float32BufferAttribute(this.skinWeights, 4));
      geometry.setIndex(this.indices);
      return geometry;
    }
  }

  function sphereGeo(cx, cy, cz, rx, ry, rz, wSeg, hSeg) {
    const geometry = new THREE.SphereGeometry(1, wSeg || 22, hSeg || 16);
    const matrix = new THREE.Matrix4()
      .makeTranslation(cx, cy, cz)
      .multiply(new THREE.Matrix4().makeScale(rx, ry, rz));
    geometry.applyMatrix4(matrix);
    geometry.normalizeNormals();
    return geometry;
  }

  // Capped cylinder from point a (top) to point b (bottom). Caps stay —
  // folded poses can expose the ends, and open tubes read as boxes.
  function tubeGeo(a, b, rTop, rBottom) {
    const axis = v3(a.x - b.x, a.y - b.y, a.z - b.z);
    const length = axis.length();
    const geometry = new THREE.CylinderGeometry(rTop, rBottom, length, 12, 1, false);
    const quaternion = new THREE.Quaternion().setFromUnitVectors(v3(0, 1, 0), axis.clone().normalize());
    const mid = v3((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2);
    const matrix = new THREE.Matrix4().compose(mid, quaternion, v3(1, 1, 1));
    geometry.applyMatrix4(matrix);
    geometry.normalizeNormals();
    return geometry;
  }

  // Chunky tabby bands along the body axis with wobble so they read
  // hand-painted rather than mathematical.
  function stripeField(p) {
    const wave = Math.sin(p.x * 30 + Math.sin(p.z * 11) * 1.6 + Math.sin(p.y * 15) * 0.9);
    const breakup = 0.72 + Math.sin(p.x * 71 + p.z * 31) * 0.28;
    const s = wave * breakup;
    return THREE.MathUtils.smoothstep(s, 0.35, 0.75);
  }

  // Soft-edged organic blobs for calico patches: two decorrelated fields
  // (one per patch color) built from beating sines — deterministic, so the
  // coat is stable across reloads of the same variant.
  function patchField(p, ox) {
    return Math.sin(p.x * 6.8 + ox)
      * Math.sin(p.y * 8.7 + ox * 1.7 + 1.3)
      * Math.sin(p.z * 16.0 + p.x * 3.1 + ox * 0.6);
  }

  // The coat system: each palette declares a pattern engine. 'tabby'
  // (default) is the striped coat; 'solid' is uniform with a soft belly;
  // 'pointed' is the Siamese scheme (dark mask, ears, legs, tail on a pale
  // body); 'tuxedo' lays a white bib, belly, and paws over black; 'calico'
  // scatters orange and black patches over white.
  function makeColorHelpers(palette, stripeAmount) {
    const base = new THREE.Color(palette.base);
    const stripe = new THREE.Color(palette.stripe);
    const belly = new THREE.Color(palette.belly);
    const sock = new THREE.Color(palette.sock);
    const muzzle = new THREE.Color(palette.muzzle);
    const patch = new THREE.Color(palette.patch || palette.stripe);
    const scratch = new THREE.Color();
    const pattern = palette.pattern || 'tabby';
    // 0 = solid coat, 1 = default markings, up to ~1.5 = bold.
    const stripes = THREE.MathUtils.clamp(stripeAmount === undefined ? 1 : stripeAmount, 0, 1.5);

    // How strongly the pattern engine marks this point of the body.
    function markings(p, region) {
      switch (pattern) {
        case 'solid':
          return 0;
        case 'pointed': {
          // Points: muzzle/face front, ear tips, low legs, handled mostly
          // per-region; body stays pale with a faint dorsal shading.
          if (region === 'tail') return 1;
          if (region === 'leg') return THREE.MathUtils.smoothstep(0.24 - p.y, 0, 0.14);
          if (region === 'head') {
            const mask = THREE.MathUtils.smoothstep(p.x - 0.585, 0, 0.07)
              + THREE.MathUtils.smoothstep(p.y - 0.745, 0, 0.05);
            return Math.min(1, mask);
          }
          return THREE.MathUtils.smoothstep(p.y - 0.55, 0, 0.12) * 0.18;
        }
        case 'tuxedo':
          return 0;
        case 'calico': {
          const f = patchField(p, region === 'head' ? 2.4 : 0.8);
          return THREE.MathUtils.smoothstep(f, 0.34, 0.55) * Math.min(1, stripes + 0.4);
        }
        default: // tabby
          if (region === 'tail') return 0; // rings handled in tailColor
          if (region === 'head') {
            // Tabby facial striping fades in from the brow up over the
            // forehead and crown (the "M" and crown stripes), leaving the
            // muzzle clean. Stronger and lower than before so the face reads
            // as a real tabby, not a plain mask.
            const facemask = THREE.MathUtils.smoothstep(p.y, 0.60, 0.69);
            return Math.min(1, stripeField(p) * 0.55 * stripes * facemask);
          }
          if (region === 'leg') {
            return p.y > 0.3 ? Math.min(1, stripeField(p) * 0.35 * stripes) : 0;
          }
          return p.y > 0.40 ? Math.min(1, stripeField(p) * 0.55 * stripes) : 0;
      }
    }

    // Second patch color for calico (black over the orange field).
    function calicoSecond(p) {
      const f = patchField(p, 4.9);
      return THREE.MathUtils.smoothstep(f, 0.40, 0.60);
    }

    function torsoColor(p) {
      scratch.copy(base);
      scratch.lerp(stripe, markings(p, 'torso'));
      if (pattern === 'calico') scratch.lerp(patch, calicoSecond(p));
      if (pattern === 'tuxedo') {
        // White bib up the chest and down the belly.
        const bib = THREE.MathUtils.smoothstep(p.x - 0.10, 0, 0.18)
          * THREE.MathUtils.smoothstep(0.56 - p.y, 0, 0.10);
        scratch.lerp(belly, Math.min(1, bib * 1.2));
      }
      const bellyMix = THREE.MathUtils.smoothstep(0.42 - p.y, 0.0, 0.13);
      scratch.lerp(belly, bellyMix * 0.9);
      return scratch;
    }

    function headColor(p) {
      scratch.copy(base);
      scratch.lerp(stripe, markings(p, 'head'));
      if (pattern === 'calico') scratch.lerp(patch, calicoSecond(p));
      const chinMix = THREE.MathUtils.smoothstep(0.62 - p.y, 0.0, 0.05);
      scratch.lerp(muzzle, chinMix * 0.7);
      return scratch;
    }

    function tailColor(p) {
      const along = THREE.MathUtils.clamp((-0.44 - p.x) / 0.56, 0, 1);
      scratch.copy(base);
      if (pattern === 'tabby') {
        const ring = THREE.MathUtils.smoothstep(Math.sin(along * 19), 0.2, 0.7);
        scratch.lerp(stripe, Math.min(1, ring * 0.8 * stripes));
        if (along > 0.86 && stripes > 0.15) scratch.copy(stripe);
      } else {
        scratch.lerp(stripe, markings(p, 'tail'));
        if (pattern === 'calico') scratch.lerp(patch, calicoSecond(p));
        if (pattern === 'tuxedo' && along > 0.88) scratch.copy(belly); // white tip
      }
      return scratch;
    }

    function legColor(p) {
      scratch.copy(base);
      scratch.lerp(stripe, markings(p, 'leg'));
      if (pattern === 'calico') scratch.lerp(patch, calicoSecond(p));
      // Socks: white paws for tuxedo/calico/tabby palettes, dark points
      // for siamese (sock color carries the intent per palette).
      const sockHeight = pattern === 'tuxedo' ? 0.22 : 0.16;
      const sockMix = THREE.MathUtils.smoothstep(sockHeight - p.y, 0.0, 0.08);
      scratch.lerp(sock, sockMix);
      return scratch;
    }

    return { torsoColor, headColor, tailColor, legColor, sock, muzzle };
  }

  function torsoWeights(p) {
    if (p.x < -0.05) {
      const t = THREE.MathUtils.clamp((p.x + 0.32) / 0.27, 0, 1);
      return [['hips', 1 - t], ['spine', t]];
    }
    const t = THREE.MathUtils.clamp((p.x + 0.05) / 0.31, 0, 1);
    return [['spine', 1 - t], ['chest', t]];
  }

  function tailWeights(p) {
    const along = THREE.MathUtils.clamp((-0.44 - p.x) / 0.525, 0, 0.999);
    const f = along * 5;
    const i = Math.floor(f);
    const t = f - i;
    const a = 'tail' + Math.min(6, i + 1);
    const b = 'tail' + Math.min(6, i + 2);
    return [[a, 1 - t], [b, t]];
  }

  function addTorso(acc, colors, chub) {
    const opts = { colorFn: colors.torsoColor, weightFn: torsoWeights };
    const bellyFur = (p) => 1.0 + Math.max(0, (0.44 - p.y)) * 1.6;
    // Chubbiness fills out depth/width more than length.
    const long = 1 + (chub - 1) * 0.35;
    // Deep chest and low-slung belly: cat proportions, not dog-on-stilts.
    acc.add(sphereGeo(-0.25, 0.445, 0, 0.21 * long, 0.19 * chub, 0.16 * chub), { ...opts, furFn: bellyFur });
    acc.add(sphereGeo(-0.005, 0.44 - (chub - 1) * 0.04, 0, 0.245 * long, 0.20 * chub, 0.17 * chub), { ...opts, furFn: bellyFur });
    acc.add(sphereGeo(0.23, 0.45, 0, 0.20 * long, 0.185 * chub, 0.155 * chub), { ...opts, fur: 0.95 });
  }

  function addHead(acc, colors) {
    const headW = () => [['head', 1]];
    const neckW = (p) => {
      const t = THREE.MathUtils.clamp((p.y - 0.47) / 0.13, 0, 1);
      return [['chest', 1 - t], ['neck', t]];
    };
    acc.add(sphereGeo(0.395, 0.555, 0, 0.125, 0.12, 0.115), {
      colorFn: colors.torsoColor, fur: 0.8, weightFn: neckW
    });
    acc.add(sphereGeo(0.515, 0.655, 0, 0.14, 0.12, 0.12), {
      colorFn: colors.headColor, fur: 0.55, weightFn: headW
    });
    for (const z of [0.07, -0.07]) {
      acc.add(sphereGeo(0.545, 0.615, z, 0.065, 0.052, 0.055, 16, 12), {
        colorFn: colors.headColor, fur: 0.75, weightFn: headW
      });
    }
    acc.add(sphereGeo(0.625, 0.617, 0, 0.075, 0.055, 0.068, 16, 12), {
      color: colors.muzzle, fur: 0.25, weightFn: headW
    });
    for (const z of [0.045, -0.045]) {
      acc.add(sphereGeo(0.652, 0.606, z, 0.048, 0.034, 0.040, 16, 10), {
        color: colors.muzzle, fur: 0.18, weightFn: headW
      });
    }
    for (const z of [0.068, -0.068]) {
      const side = z > 0 ? 1 : -1;
      // A real cat ear is a thin triangular flap, not a fat cone. Flatten
      // the cone front-to-back, widen the base, and turn the broad face
      // forward-and-out so the cupped pinna reads from the front.
      const ear = new THREE.ConeGeometry(0.058, 0.150, 16);
      const matrix = new THREE.Matrix4()
        .makeTranslation(0.487, 0.800, z)
        .multiply(new THREE.Matrix4().makeRotationX(side * 0.34))
        .multiply(new THREE.Matrix4().makeRotationZ(-0.08))
        .multiply(new THREE.Matrix4().makeRotationY(side * 0.40))
        .multiply(new THREE.Matrix4().makeScale(1.22, 1.02, 0.66));
      ear.applyMatrix4(matrix);
      ear.normalizeNormals();
      acc.add(ear, { colorFn: colors.headColor, fur: 0.26, weightFn: headW });
    }
  }

  function addTail(acc, colors) {
    const opts = { colorFn: colors.tailColor, weightFn: tailWeights };
    const segments = 13;
    for (let i = 0; i <= segments; i++) {
      const t = i / segments;
      const x = -0.44 - t * 0.55;
      const y = 0.50 - t * 0.045;
      const r = 0.054 - t * 0.024;
      acc.add(sphereGeo(x, y, 0, r * 1.15, r, r, 12, 9), {
        ...opts, fur: 1.25 + t * 0.3
      });
    }
  }

  function addLeg(acc, colors, prefix, isFront, x, z) {
    const side = prefix.endsWith('L') ? 'L' : 'R';
    const thigh = isFront ? 'shoulderF' + side : 'thighB' + side;
    const shin = isFront ? 'elbowF' + side : 'shinB' + side;
    const foot = prefix;
    const hipY = isFront ? 0.44 : 0.42;
    const kneeY = isFront ? 0.235 : 0.23;
    const footY = isFront ? 0.05 : 0.055;
    const legOpts = { colorFn: colors.legColor };

    // Weights blend smoothly across each joint so the skin bends like a
    // hose instead of two rigid tubes clipping through each other.
    const upperTubeWeights = (p) => {
      const t = THREE.MathUtils.clamp((hipY - p.y) / (hipY - kneeY), 0, 1);
      const shinShare = 0.5 * THREE.MathUtils.smoothstep(t, 0.55, 1.0);
      return [[thigh, 1 - shinShare], [shin, shinShare]];
    };
    const lowerTubeWeights = (p) => {
      const t = THREE.MathUtils.clamp((kneeY - p.y) / (kneeY - footY), 0, 1);
      const thighShare = 0.5 * (1 - THREE.MathUtils.smoothstep(t, 0.0, 0.45));
      const footShare = 0.5 * THREE.MathUtils.smoothstep(t, 0.55, 1.0);
      return [[thigh, thighShare], [shin, 1 - thighShare - footShare], [foot, footShare]];
    };

    // Haunch / shoulder mass blends the leg into the torso.
    acc.add(sphereGeo(x, hipY + 0.03, z, isFront ? 0.09 : 0.115, isFront ? 0.115 : 0.135, 0.078, 16, 12), {
      colorFn: colors.torsoColor, fur: 0.9,
      weightFn: () => [[thigh, 0.55], [isFront ? 'chest' : 'hips', 0.45]]
    });
    acc.add(tubeGeo(v3(x, hipY, z), v3(x, kneeY, z), 0.075, 0.052), {
      ...legOpts, fur: 0.5, weightFn: upperTubeWeights
    });
    acc.add(sphereGeo(x, kneeY, z, 0.056, 0.056, 0.052, 14, 10), {
      ...legOpts, fur: 0.45,
      weightFn: () => [[thigh, 0.5], [shin, 0.5]]
    });
    acc.add(tubeGeo(v3(x, kneeY, z), v3(x, footY, z), 0.05, 0.04), {
      ...legOpts, fur: 0.45, weightFn: lowerTubeWeights
    });
    acc.add(sphereGeo(x, footY - 0.005, z, 0.04, 0.042, 0.04, 12, 9), {
      ...legOpts, fur: 0.3,
      weightFn: () => [[shin, 0.5], [foot, 0.5]]
    });
    acc.add(sphereGeo(x + 0.022, 0.04, z, 0.058, 0.04, 0.046, 14, 10), {
      color: colors.sock, fur: 0.25,
      weightFn: () => [[shin, 0.15], [foot, 0.85]]
    });
  }

  // Redrawable eye: the pupil dilates with arousal (calm slit → hunting
  // pool), so the texture is rebuilt on demand rather than baked once.
  function makeEyeKit(palette) {
    const size = FACE_DETAIL_SPEC.eyeTextureSize;
    const canvas = document.createElement('canvas');
    canvas.width = size;
    canvas.height = size;
    const ctx = canvas.getContext('2d');
    const cx = size / 2;
    const cy = size * 0.48;
    const texture = new THREE.CanvasTexture(canvas);
    let lastDilation = -1;

    // Mix a hex color toward white / black by t in [0,1].
    function hexRGB(h) {
      const n = parseInt(h.slice(1), 16);
      return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
    }
    function lighten(h, t) {
      const [r, g, b] = hexRGB(h);
      return 'rgb(' + Math.round(r + (255 - r) * t) + ',' +
        Math.round(g + (255 - g) * t) + ',' + Math.round(b + (255 - b) * t) + ')';
    }
    function darken(h, t) {
      const [r, g, b] = hexRGB(h);
      return 'rgb(' + Math.round(r * (1 - t)) + ',' +
        Math.round(g * (1 - t)) + ',' + Math.round(b * (1 - t)) + ')';
    }

    function draw(dilation) {
    // A cat's iris fills almost the whole eye — barely any sclera shows. So
    // the eye is iris edge to edge, which is what reads as a warm living eye
    // instead of a small amber disc floating in black.
    ctx.fillStyle = darken(palette.irisEdge, 0.25);
    ctx.fillRect(0, 0, size, size);

    // Luminous iris: a bright saturated centre lit from upper-left, fading
    // to a darker limbal rim. The offset highlight gives it real depth.
    const lx = cx - size * 0.07;
    const ly = cy - size * 0.08;
    const iris = ctx.createRadialGradient(lx, ly, size * 0.03, cx, cy, size * 0.54);
    iris.addColorStop(0, lighten(palette.iris, 0.55));
    iris.addColorStop(0.28, lighten(palette.iris, 0.12));
    iris.addColorStop(0.62, palette.iris);
    iris.addColorStop(0.88, palette.irisEdge);
    iris.addColorStop(1, darken(palette.irisEdge, 0.4));
    ctx.fillStyle = iris;
    ctx.beginPath();
    ctx.arc(cx, cy, size * 0.54, 0, Math.PI * 2);
    ctx.fill();

    // Fine radial fibers keep the eye from reading like a flat decal.
    ctx.save();
    ctx.translate(cx, cy);
    ctx.strokeStyle = 'rgba(255,246,200,0.20)';
    ctx.lineWidth = 1;
    for (let i = 0; i < 56; i++) {
      const a = (Math.PI * 2 * i) / 56 + Math.sin(i * 7.1) * 0.04;
      const r0 = size * (0.13 + (i % 3) * 0.016);
      const r1 = size * (0.44 + (i % 5) * 0.012);
      ctx.beginPath();
      ctx.moveTo(Math.cos(a) * r0, Math.sin(a) * r0);
      ctx.lineTo(Math.cos(a) * r1, Math.sin(a) * r1);
      ctx.stroke();
    }
    ctx.restore();

    // Thin dark limbal ring crisply bounds the iris.
    ctx.strokeStyle = 'rgba(14,11,8,0.5)';
    ctx.lineWidth = size * 0.024;
    ctx.beginPath();
    ctx.arc(cx, cy, size * 0.52, 0, Math.PI * 2);
    ctx.stroke();

    // Pupil: width swells from slit toward round with dilation; the
    // height barely changes, exactly like a real cat's vertical pupil.
    ctx.fillStyle = '#0b0a07';
    ctx.beginPath();
    ctx.ellipse(
      cx, cy,
      size * (0.060 + dilation * 0.235),
      size * (0.40 + dilation * 0.05),
      0, 0, Math.PI * 2
    );
    ctx.fill();
    // Faint warm rim where the iris catches light against the pupil.
    ctx.strokeStyle = 'rgba(255,236,168,0.15)';
    ctx.lineWidth = size * 0.018;
    ctx.beginPath();
    ctx.ellipse(
      cx, cy,
      size * (0.072 + dilation * 0.235),
      size * (0.42 + dilation * 0.05),
      0, 0, Math.PI * 2
    );
    ctx.stroke();

    // Upper-lid shadow: a real eye is shaded at the top where the lid
    // overhangs and lit toward the bottom. This depth is what stops the eye
    // reading as a flat printed ball.
    ctx.save();
    ctx.beginPath();
    ctx.arc(cx, cy, size * 0.54, 0, Math.PI * 2);
    ctx.clip();
    const lid = ctx.createLinearGradient(0, cy - size * 0.54, 0, cy + size * 0.18);
    lid.addColorStop(0, 'rgba(6,4,3,0.5)');
    lid.addColorStop(0.5, 'rgba(6,4,3,0.16)');
    lid.addColorStop(1, 'rgba(6,4,3,0)');
    ctx.fillStyle = lid;
    ctx.fillRect(0, 0, size, size);
    ctx.restore();

    // Catchlight: a bright soft primary highlight + a tiny secondary. The
    // wet specular is what makes an eye look alive.
    const glx = cx - size * 0.13, gly = cy - size * 0.17;
    const hl = ctx.createRadialGradient(glx, gly, 1, glx, gly, size * 0.105);
    hl.addColorStop(0, 'rgba(255,255,253,0.98)');
    hl.addColorStop(0.55, 'rgba(255,255,250,0.5)');
    hl.addColorStop(1, 'rgba(255,255,250,0)');
    ctx.fillStyle = hl;
    ctx.beginPath();
    ctx.arc(glx, gly, size * 0.105, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = 'rgba(255,255,255,0.42)';
    ctx.beginPath();
    ctx.arc(cx + size * 0.12, cy + size * 0.10, size * 0.022, 0, Math.PI * 2);
    ctx.fill();
    }

    function setDilation(dilation) {
      const clamped = Math.min(1, Math.max(0, dilation));
      // Coarser step: the pupil texture is a CanvasTexture re-upload, so only
      // redraw on a meaningful dilation change (cheaper during hunting swings).
      if (Math.abs(clamped - lastDilation) < 0.045) return;
      lastDilation = clamped;
      draw(clamped);
      texture.needsUpdate = true;
    }

    setDilation(0);
    return { texture, setDilation };
  }

  function attachToBone(bone, restPos, mesh, worldPos) {
    mesh.position.set(worldPos.x - restPos.x, worldPos.y - restPos.y, worldPos.z - restPos.z);
    bone.add(mesh);
  }

  // A whisker is a stiff hair: it leaves the pad straight, sweeps outward,
  // then gravity takes the unsupported tip — quadratic sag concentrated in
  // the outer half. Top rows arc up before sagging; bottom rows droop from
  // the start, like a real muzzle fan.
  function makeWhiskerGeometry(length, side, row) {
    const lift = (2 - row) * 0.016;
    const outward = side * (0.052 + row * 0.013);
    const sag = 0.020 + row * 0.009;
    const points = [];
    const segments = 6;
    for (let i = 0; i <= segments; i++) {
      const t = i / segments;
      points.push(v3(
        length * t,
        lift * Math.sin(t * Math.PI * 0.62) - sag * t * t * 1.45,
        outward * (t * 0.82 + t * t * 0.18)
      ));
    }
    const curve = new THREE.CatmullRomCurve3(points);
    return new THREE.TubeGeometry(curve, 12, 0.0012 - row * 0.00008, 5, false);
  }

  function addFaceDetails(skeleton, palette) {
    const head = skeleton.byName.head;
    const headRest = skeleton.rest.head;
    const eyeKit = makeEyeKit(palette);
    const eyeTexture = eyeKit.texture;
    const eyes = [];
    const whiskers = [];
    const innerEars = [];
    const lidColor = new THREE.Color(palette.stripe).lerp(new THREE.Color(0x17120f), 0.32);
    const eyelidMaterial = new THREE.MeshBasicMaterial({
      color: lidColor, transparent: true, opacity: 0.82, depthWrite: false
    });
    const whiskerMaterial = new THREE.MeshBasicMaterial({
      color: 0xfdfbf4, transparent: true, opacity: 0.72, depthWrite: false
    });
    const whiskerRootMaterial = new THREE.MeshBasicMaterial({
      color: 0xd9c8ba, transparent: true, opacity: 0.88, depthWrite: false
    });
    const mouthMaterial = new THREE.MeshBasicMaterial({
      color: 0x3a2824, transparent: true, opacity: 0.46, depthWrite: false
    });
    const tongueMaterial = new THREE.MeshBasicMaterial({
      color: new THREE.Color(0xe98996).lerp(new THREE.Color(palette.nose), 0.24),
      transparent: true,
      opacity: 0.94,
      depthWrite: false
    });
    const noseBridgeMaterial = new THREE.MeshBasicMaterial({
      color: new THREE.Color(palette.nose).lerp(new THREE.Color(0x2b211f), 0.22),
      transparent: true,
      opacity: 0.72,
      depthWrite: false
    });

    for (const z of [0.062, -0.062]) {
      const pivot = new THREE.Group();
      const eye = new THREE.Mesh(
        new THREE.SphereGeometry(0.0375, 24, 16),
        new THREE.MeshBasicMaterial({ map: eyeTexture })
      );
      eye.scale.set(0.9, 1, 1);
      eye.renderOrder = 20;
      pivot.add(eye);
      // Dark eye rim (eyeliner): the crisp dark line right around the eye.
      const rim = new THREE.Mesh(new THREE.TorusGeometry(0.0368, 0.0036, 8, 30), eyelidMaterial);
      rim.rotation.y = Math.PI / 2;
      rim.scale.set(1.0, 0.80, 1.0);
      rim.renderOrder = 21;
      pivot.add(rim);
      const upperLid = new THREE.Mesh(new THREE.SphereGeometry(0.035, 16, 8), eyelidMaterial);
      upperLid.scale.set(0.92, 0.18, 0.26);
      upperLid.position.set(0.006, 0.028, 0);
      upperLid.renderOrder = 22;
      pivot.add(upperLid);
      const lowerLid = new THREE.Mesh(new THREE.SphereGeometry(0.034, 16, 8), eyelidMaterial);
      lowerLid.scale.set(0.84, 0.115, 0.20);
      lowerLid.position.set(0.004, -0.026, 0);
      lowerLid.renderOrder = 22;
      pivot.add(lowerLid);
      // Negative y-rotation swings the +x-facing iris toward +z (the
      // viewer side) for the near eye; mirrored for the far eye. Eased back
      // from 0.38 so the iris faces more forward and the eye reads warm
      // (not edge-on dark) even when looking near head-on.
      pivot.rotation.y = z > 0 ? -0.30 : 0.30;
      // Outer canthus lifted slightly for the almond cat-eye shape.
      pivot.rotation.z = z > 0 ? -0.10 : 0.10;
      // Sits just proud of the head sphere surface so the full eye shows.
      attachToBone(head, headRest, pivot, v3(0.601, 0.686, z > 0 ? 0.076 : -0.076));
      eyes.push({
        pivot,
        eye,
        rim,
        upperLid,
        lowerLid,
        upperBaseY: upperLid.position.y,
        lowerBaseY: lowerLid.position.y
      });
    }

    const bridge = new THREE.Mesh(
      new THREE.CylinderGeometry(0.004, 0.006, 0.082, 7, 1, false),
      noseBridgeMaterial
    );
    bridge.rotation.z = -0.30;
    bridge.renderOrder = 21;
    attachToBone(head, headRest, bridge, v3(0.664, 0.660, 0));

    const nose = new THREE.Mesh(
      new THREE.SphereGeometry(0.021, 18, 12),
      new THREE.MeshBasicMaterial({ color: palette.nose })
    );
    nose.scale.set(0.96, 0.74, 1.04);
    nose.renderOrder = 22;
    attachToBone(head, headRest, nose, v3(0.700, 0.634, 0));
    // Wet sheen on the nose leather — a small bright highlight near the top.
    const noseShine = new THREE.Mesh(
      new THREE.SphereGeometry(0.0055, 8, 6),
      new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.5, depthWrite: false })
    );
    noseShine.renderOrder = 23;
    attachToBone(head, headRest, noseShine, v3(0.713, 0.643, 0.006));
    // Two nostril dimples on the lower flanks of the nose.
    const nostrilMaterial = new THREE.MeshBasicMaterial({
      color: new THREE.Color(palette.nose).lerp(new THREE.Color(0x1a1210), 0.55),
      transparent: true, opacity: 0.8, depthWrite: false
    });
    for (const s of [1, -1]) {
      const nostril = new THREE.Mesh(new THREE.SphereGeometry(0.0040, 8, 6), nostrilMaterial);
      nostril.scale.set(0.8, 1.3, 0.8);
      nostril.renderOrder = 23;
      attachToBone(head, headRest, nostril, v3(0.708, 0.628, s * 0.0105));
    }
    // Chin: a small cream bump below the mouth so the lower muzzle has
    // structure instead of melting into the neck fur.
    const chin = new THREE.Mesh(
      new THREE.SphereGeometry(0.026, 12, 10),
      new THREE.MeshBasicMaterial({
        color: new THREE.Color(palette.muzzle).lerp(new THREE.Color(palette.base), 0.18),
        transparent: true, opacity: 0.55, depthWrite: false
      })
    );
    chin.scale.set(0.95, 0.72, 0.92);
    chin.renderOrder = 18;
    attachToBone(head, headRest, chin, v3(0.676, 0.576, 0));

    const philtrum = new THREE.Mesh(
      new THREE.CylinderGeometry(0.0015, 0.0015, 0.034, 5, 1, false),
      mouthMaterial
    );
    philtrum.rotation.z = -0.04;
    philtrum.renderOrder = 21;
    attachToBone(head, headRest, philtrum, v3(0.693, 0.611, 0));
    for (const side of [1, -1]) {
      const mouth = new THREE.Mesh(
        new THREE.CylinderGeometry(0.0013, 0.0013, 0.048, 5, 1, false),
        mouthMaterial
      );
      mouth.rotation.x = Math.PI / 2;
      mouth.rotation.z = side * 0.20;
      mouth.renderOrder = 21;
      attachToBone(head, headRest, mouth, v3(0.682, 0.600, side * 0.018));
    }

    const tongueGroup = new THREE.Group();
    tongueGroup.visible = false;
    tongueGroup.renderOrder = 25;
    const tongueBody = new THREE.Mesh(new THREE.SphereGeometry(0.017, 16, 10), tongueMaterial);
    tongueBody.scale.set(1.45, 0.42, 0.30);
    tongueBody.renderOrder = 25;
    tongueGroup.add(tongueBody);
    const tongueTip = new THREE.Mesh(new THREE.SphereGeometry(0.012, 14, 8), tongueMaterial);
    tongueTip.scale.set(0.80, 0.46, 0.34);
    tongueTip.position.set(0.024, -0.001, 0);
    tongueTip.renderOrder = 26;
    tongueGroup.add(tongueTip);
    attachToBone(head, headRest, tongueGroup, v3(0.705, 0.596, 0));
    const tongue = {
      group: tongueGroup,
      body: tongueBody,
      tip: tongueTip,
      basePosition: tongueGroup.position.clone(),
      baseRotation: tongueGroup.rotation.clone()
    };

    // The whisker pads: unlit overlays read as two glowing white discs at
    // full opacity. Warmed toward the coat and dropped to a soft wash so
    // they suggest a muzzle instead of a clown nose, and flattened so the
    // two pads merge into one form.
    const cheekPadMaterial = new THREE.MeshBasicMaterial({
      color: new THREE.Color(palette.muzzle).lerp(new THREE.Color(palette.base), 0.22),
      transparent: true,
      opacity: 0.5,
      depthWrite: false
    });
    for (const side of [1, -1]) {
      const cheekPad = new THREE.Mesh(new THREE.SphereGeometry(0.038, 14, 8), cheekPadMaterial);
      cheekPad.scale.set(1.16, 0.62, 0.82);
      cheekPad.renderOrder = 19;
      attachToBone(head, headRest, cheekPad, v3(0.668, 0.600, side * 0.038));
      for (let i = 0; i < FACE_DETAIL_SPEC.whiskersPerSide; i++) {
        const length = 0.178 + i * 0.022 + (i % 2) * 0.010;
        const baseY = 0.618 - i * 0.009;
        const baseZ = side * (0.040 + Math.min(i, 3) * 0.006);
        const group = new THREE.Group();
        const whisker = new THREE.Mesh(
          makeWhiskerGeometry(length, side, i),
          whiskerMaterial
        );
        whisker.renderOrder = 20;
        group.add(whisker);
        const rootDot = new THREE.Mesh(
          new THREE.SphereGeometry(0.0045 - i * 0.00025, 8, 6),
          whiskerRootMaterial
        );
        rootDot.renderOrder = 22;
        group.add(rootDot);
        group.rotation.y = side * (0.012 + i * 0.012);
        group.rotation.z = -0.025 - i * 0.010;
        const baseRotationY = group.rotation.y;
        const baseRotationZ = group.rotation.z;
        attachToBone(head, headRest, group, v3(0.646, baseY, baseZ));
        whiskers.push({
          mesh: group,
          fiber: whisker,
          rootDot,
          side,
          index: i,
          sensitivity: 1 - i * 0.08,
          baseRotationY,
          baseRotationZ
        });
      }
    }
    // Superciliary whiskers: the short brow hairs above each eye. Cats
    // read as "cat" largely because of these — two or three fine hairs
    // sweeping up and back from the brow ridge.
    for (const side of [1, -1]) {
      for (let i = 0; i < 3; i++) {
        const length = 0.085 + i * 0.018;
        const group = new THREE.Group();
        const brow = new THREE.Mesh(
          makeWhiskerGeometry(length, side, 0),
          whiskerMaterial
        );
        brow.renderOrder = 20;
        group.add(brow);
        // Swept up and back over the skull, fanned slightly per hair.
        group.rotation.z = 0.62 + i * 0.16;
        group.rotation.y = side * (0.30 + i * 0.10);
        const baseRotationY = group.rotation.y;
        const baseRotationZ = group.rotation.z;
        attachToBone(head, headRest, group, v3(
          0.582, 0.722 + i * 0.006, side * (0.058 + i * 0.004)
        ));
        whiskers.push({
          mesh: group,
          fiber: brow,
          side,
          index: i,
          sensitivity: 0.55 - i * 0.08,
          baseRotationY,
          baseRotationZ
        });
      }
    }

    // The pinna bowl: a flattened pink cone seated just proud of the front
    // face of each ear flap, oriented to match the outer ear so the
    // concave inner surface reads from the front. Slightly muted from the
    // nose pink so it doesn't glow.
    const innerEarMaterial = new THREE.MeshBasicMaterial({
      color: new THREE.Color(palette.nose).lerp(new THREE.Color(palette.muzzle), 0.30)
    });
    for (const z of [0.066, -0.066]) {
      const side = z > 0 ? 1 : -1;
      const inner = new THREE.Mesh(new THREE.ConeGeometry(0.038, 0.104, 12), innerEarMaterial);
      inner.scale.set(1.10, 1.0, 0.56);
      const baseRotationX = side * 0.34;
      inner.rotation.x = baseRotationX;
      inner.rotation.z = -0.08;
      inner.rotation.y = side * 0.40;
      attachToBone(head, headRest, inner, v3(0.498, 0.796, side * 0.062));
      innerEars.push({ mesh: inner, side, baseRotationX });
    }
    return { eyes, whiskers, innerEars, tongue, setPupilDilation: eyeKit.setDilation };
  }

  // Retractable claws: three small curved hooks per paw, parented to the
  // foot bones so they ride every pose. Normally sheathed (scaled to
  // nothing); the animator extends them for climbing, scratching, and
  // clinging — exactly when a real cat unsheathes.
  function addClaws(skeleton) {
    const clawMaterial = new THREE.MeshBasicMaterial({
      color: 0xe9e2d2, transparent: true, opacity: 0.95, depthWrite: false
    });
    const clawSets = [];
    const feet = [
      ['footFL', 0.30, 0.05], ['footFR', 0.30, 0.05],
      ['footBL', -0.28, 0.055], ['footBR', -0.28, 0.055]
    ];
    for (const [footName] of feet.map(f => [f[0]])) {
      const foot = skeleton.byName[footName];
      const set = new THREE.Group();
      for (let i = 0; i < 3; i++) {
        // A claw is a slim curved cone: out of the toe, hooking down.
        const claw = new THREE.Mesh(
          new THREE.ConeGeometry(0.0042, 0.034, 6),
          clawMaterial
        );
        claw.position.set(0.045, -0.035, (i - 1) * 0.016);
        claw.rotation.z = -1.95 + i * 0.06; // tip sweeps forward-down
        claw.renderOrder = 21;
        set.add(claw);
      }
      set.scale.setScalar(0.001); // sheathed
      foot.add(set);
      clawSets.push(set);
    }
    return clawSets;
  }

  function makeShadowBlob() {
    const size = 256;
    const canvas = document.createElement('canvas');
    canvas.width = size;
    canvas.height = size;
    const ctx = canvas.getContext('2d');
    const gradient = ctx.createRadialGradient(size / 2, size / 2, 8, size / 2, size / 2, size / 2);
    gradient.addColorStop(0, 'rgba(20,28,16,0.42)');
    gradient.addColorStop(0.6, 'rgba(20,28,16,0.22)');
    gradient.addColorStop(1, 'rgba(20,28,16,0)');
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, size, size);
    const shadow = new THREE.Mesh(
      new THREE.PlaneGeometry(1.5, 0.55),
      new THREE.MeshBasicMaterial({
        map: new THREE.CanvasTexture(canvas),
        transparent: true,
        depthWrite: false
      })
    );
    shadow.rotation.x = -Math.PI / 2;
    shadow.position.y = 0.004;
    shadow.renderOrder = -1;
    return shadow;
  }

  function buildCat(variantName, lighting, seedRandom, options) {
    const opts = options || {};
    const chub = THREE.MathUtils.clamp(opts.chubbiness || 1, 0.8, 1.35);
    const palette = PALETTES[variantName] || PALETTES.orange;
    const colors = makeColorHelpers(palette, opts.stripeAmount);
    const skeleton = buildSkeleton();
    const acc = new GeometryAccumulator(skeleton.indexByName);

    addTorso(acc, colors, chub);
    addHead(acc, colors);
    addTail(acc, colors);
    addLeg(acc, colors, 'footBL', false, -0.28, 0.13);
    addLeg(acc, colors, 'footBR', false, -0.28, -0.13);
    addLeg(acc, colors, 'footFL', true, 0.30, 0.115);
    addLeg(acc, colors, 'footFR', true, 0.30, -0.115);

    const geometry = acc.build();
    const strandTexture = CatFur.makeStrandTexture(seedRandom);
    const materials = CatFur.makeShellMaterials(strandTexture, lighting);
    const furDriver = CatFur.makeUniformDriver(materials);

    const group = new THREE.Group();
    const baseMesh = new THREE.SkinnedMesh(geometry, materials[0]);
    baseMesh.frustumCulled = false;
    baseMesh.add(skeleton.byName.root);
    group.add(baseMesh);
    baseMesh.updateMatrixWorld(true);
    const threeSkeleton = new THREE.Skeleton(skeleton.list);
    baseMesh.bind(threeSkeleton);

    for (let i = 1; i <= CatFur.SHELL_COUNT; i++) {
      const shell = new THREE.SkinnedMesh(geometry, materials[i]);
      shell.frustumCulled = false;
      shell.renderOrder = i;
      shell.bind(threeSkeleton, baseMesh.bindMatrix);
      group.add(shell);
    }

    const faceDetails = addFaceDetails(skeleton, palette);
    const clawSets = addClaws(skeleton);
    const shadow = makeShadowBlob();

    return {
      group,
      shadow,
      bones: skeleton.byName,
      rest: skeleton.rest,
      eyes: faceDetails.eyes,
      whiskers: faceDetails.whiskers,
      innerEars: faceDetails.innerEars,
      tongue: faceDetails.tongue,
      setPupilDilation: faceDetails.setPupilDilation,
      // 0 = sheathed, 1 = fully out. Scales the claw sets so extension
      // animates smoothly.
      setClawsOut(amount) {
        const s = Math.max(0.001, Math.min(1, amount));
        for (const set of clawSets) {
          set.scale.setScalar(s);
        }
      },
      materials,
      furDriver,
      palette,
      setFurLength(multiplier) {
        const length = 0.085 * THREE.MathUtils.clamp(multiplier || 1, 0.4, 1.8);
        for (const material of materials) {
          material.uniforms.uFurLen.value = length;
        }
      }
    };
  }

  return { buildCat, PALETTES, FACE_DETAIL_SPEC };
})();
