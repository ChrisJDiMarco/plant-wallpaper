/* ============================================================================
 * emergence.js — DESIRE PATHS THAT PAVE THEMSELVES (drop-in, globals)
 * ----------------------------------------------------------------------------
 * three.js r128, GLOBAL THREE, classic build. NO modules / loaders / image
 * files. Loads as a plain <script> AFTER three.min.js and BEFORE main.js.
 *
 * Publishes TWO globals:
 *
 *   window.createEmergentGround(opts) ->
 *     { mesh, deposit(x,z,strength), update(dt), seedPlaza(x,z,r,amt), dispose() }
 *
 *   window.createTownRouting(opts) ->
 *     { assign(gnome), stepGnome(gnome, dt, deposit), pois }
 *
 * THE LOOP
 *   Routing walks gnomes between POIs (homes / works / wells / plaza). Every
 *   frame each walking gnome calls deposit(footX, footZ, dt) — the ground
 *   accumulates WEAR with a soft gaussian stamp. update(dt) decays the whole
 *   field (disused routes fade back to nothing) and, throttled to ~10fps,
 *   repaints ONE reused RGBA CanvasTexture: ALPHA ramps 0->1 with a soft knee
 *   so faint wear is barely visible, RGB lerps warm translucent brown dirt ->
 *   packed earth -> deep worn brown as wear rises. Where routes converge, wear
 *   stacks and a PLAZA emerges on its own. Unworn ground stays fully transparent
 *   so the desktop shows through.
 *
 * TRANSPARENT-OVERLAY CONTRACT
 *   The ground is one PlaneGeometry laid flat just above the shadow-catcher,
 *   transparent + depthWrite:false, so it composites over the desktop and never
 *   writes opaque ground. receiveShadow on so gnomes drop contact shadows onto
 *   the path. Color CanvasTexture gets encoding = sRGBEncoding (r128 API).
 * ==========================================================================*/
(function () {
  'use strict';

  /* ##########################################################################
   * ##  PART 1 — EMERGENT GROUND (grid wear-field + canvas texture)         ##
   * ##  Chosen approach: the Float32-grid model. It is the most robust for  ##
   * ##  a live overlay — explicit decay, throttled 10Hz repaint, box-blur   ##
   * ##  for organic edges, hard cell cap. The canvas-only variant is folded ##
   * ##  in via the soft palette + earth-grain noise. deposit(x,z,strength)  ##
   * ##  matches what createTownRouting passes (strength = roleW*dt amount). ##
   * ######################################################################## */

  /* ============================ TUNING CONSTANTS ============================
   * Calibrated so a route walked ~15-30 times over ~60s visibly paves, and an
   * abandoned route fades over ~90-120s. All rates are per-second so any
   * framerate converges to the same look. See MATH NOTE at the bottom.
   * ========================================================================*/

  // --- wear dynamics ---
  var DECAY_RATE      = 0.0163;  // per second exp decay; ~100s well-worn -> invisible.
  var WEAR_MAX        = 1.6;     // hard clamp so a hyper-busy hub can't over-darken.
  var PAVE_AT         = 1.0;     // wear value that reads as an established path.

  // --- deposit falloff (one footstep) ---
  // A footpath is ~1.5-3 gnome-widths (~12-22u). At cellSize ~8 that is a ~2-cell
  // radius; we stamp with a tight gaussian so edges are soft, not blocky.
  var DEPOSIT_RADIUS_CELLS = 2.0;  // kernel reach in cells (soft beyond ~1.5)
  var DEPOSIT_SIGMA        = 0.95; // gaussian sigma in cells -> tight core, soft skirt

  // --- per-deposit strength baseline ---
  // deposit(x, z, strength) multiplies `strength` by DEPOSIT_GAIN.
  // CALLER CADENCE (what these constants are tuned against): createTownRouting
  // calls deposit(footX, footZ, amount) ONCE PER GNOME PER FRAME while walking,
  // where amount ~= roleWeight * dt (frame-rate independent). At ~22 u/s a single
  // pass over a cell yields ~0.3-0.5s of gaussian-weighted exposure; with GAIN
  // 0.34 and the decay below, route-center wear reaches PAVE_AT after ~18-26
  // passes and saturates into a deeper worn-brown trail by ~32.
  var DEPOSIT_GAIN = 0.34;

  // --- texture / appearance ---
  var REPAINT_HZ      = 10;      // throttle: regenerate the texture at most 10x/s.
  var TEX_OVERSAMPLE  = 4;       // canvas pixels per grid cell (bilinear smoothing).
  var TEX_MAX         = 768;     // hard cap on canvas dimension (perf guard).
  var ALPHA_KNEE      = 0.16;    // wear below this is ~invisible (soft threshold).
  var ALPHA_FULL      = 0.95;    // wear at/above this is fully opaque path.
  var ALPHA_CEIL      = 0.62;    // stays translucent so wallpaper texture shows through.
  var GRID_BLUR_PASS  = 1;       // box-blur passes on the SAMPLED field -> organic
                                 //   soft edges. 0 = crisp.
  var NOISE_AMP       = 0.10;    // per-cell brightness jitter on earth grain,
                                 //   not a flat overlay. Stable per cell.

  // --- palette (sRGB bytes; encoding handles gamma) ---
  // warm translucent brown dirt -> packed earth -> deep worn brown.
  var COL_DIRT   = [150, 105,  64];
  var COL_EARTH  = [118,  75,  42];
  var COL_COBBLE = [ 86,  54,  32];
  var BAND_EARTH  = 0.45;  // dirt -> earth crossover (wear value)
  var BAND_COBBLE = 0.95;  // earth -> cobble crossover (wear value)

  var GRID_CAP = 120;      // max cells per side (hard cap; keeps the loop cheap)

  /* ============================== HELPERS ================================= */
  function clamp(v, lo, hi) { return v < lo ? lo : v > hi ? hi : v; }
  function smoothstep(e0, e1, x) {
    if (e1 === e0) return x < e0 ? 0 : 1;
    var t = clamp((x - e0) / (e1 - e0), 0, 1);
    return t * t * (3 - 2 * t);
  }
  function lerp(a, b, t) { return a + (b - a) * t; }
  function lerp3(a, b, t, out) {
    out[0] = a[0] + (b[0] - a[0]) * t;
    out[1] = a[1] + (b[1] - a[1]) * t;
    out[2] = a[2] + (b[2] - a[2]) * t;
    return out;
  }
  // cheap stable hash -> [0,1) for per-cell noise (no allocation, no PRNG state)
  function hash01(i, j) {
    var h = (i * 374761393 + j * 668265263) | 0;
    h = (h ^ (h >>> 13)) * 1274126177 | 0;
    return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
  }

  /* ============================ GROUND FACTORY =========================== */
  window.createEmergentGround = function createEmergentGround(opts) {
    opts = opts || {};
    var bounds = opts.bounds;
    if (!bounds) throw new Error('createEmergentGround: opts.bounds required');

    var minX = bounds.minX, maxX = bounds.maxX, minZ = bounds.minZ, maxZ = bounds.maxZ;
    var spanX = Math.max(1e-3, maxX - minX);
    var spanZ = Math.max(1e-3, maxZ - minZ);
    var y = (opts.y != null) ? opts.y : 0.4;

    // ---- resolve grid resolution ----
    var nx, nz;
    if (opts.resolution) {
      nx = nz = Math.min(GRID_CAP, Math.max(8, opts.resolution | 0));
    } else {
      var cell = opts.cellSize || 8;
      nx = clamp(Math.round(spanX / cell), 8, GRID_CAP);
      nz = clamp(Math.round(spanZ / cell), 8, GRID_CAP);
    }
    var cellW = spanX / nx;  // world units per cell along X
    var cellH = spanZ / nz;  // world units per cell along Z

    // ---- wear field + scratch buffers (allocated ONCE) ----
    var wear    = new Float32Array(nx * nz);
    var blurBuf = new Float32Array(nx * nz);  // reused by the blur pass

    /* ---- world <-> grid mapping (cell CENTERS map to world) ---- */
    function gx(worldX) { return (worldX - minX) / cellW - 0.5; } // fractional col
    function gz(worldZ) { return (worldZ - minZ) / cellH - 0.5; } // fractional row

    /* ======================= DEPOSIT ================================= *
     * Soft gaussian stamp around (worldX, worldZ). strength scales the gain.
     * createTownRouting passes strength = (roleWeight * dt). */
    function deposit(worldX, worldZ, strength) {
      if (strength == null) strength = 1;
      var amp = strength * DEPOSIT_GAIN;
      if (amp <= 0) return;

      var cx = gx(worldX), cz = gz(worldZ);
      var R = DEPOSIT_RADIUS_CELLS;
      var i0 = Math.floor(cx - R), i1 = Math.ceil(cx + R);
      var j0 = Math.floor(cz - R), j1 = Math.ceil(cz + R);
      i0 = i0 < 0 ? 0 : i0; j0 = j0 < 0 ? 0 : j0;
      i1 = i1 >= nx ? nx - 1 : i1; j1 = j1 >= nz ? nz - 1 : j1;

      var inv2s2 = 1 / (2 * DEPOSIT_SIGMA * DEPOSIT_SIGMA);
      for (var j = j0; j <= j1; j++) {
        var dz = j - cz;
        var row = j * nx;
        for (var i = i0; i <= i1; i++) {
          var dx = i - cx;
          var d2 = dx * dx + dz * dz;
          if (d2 > R * R) continue;
          var w = Math.exp(-d2 * inv2s2);           // gaussian falloff
          var idx = row + i;
          var v = wear[idx] + amp * w;
          wear[idx] = v > WEAR_MAX ? WEAR_MAX : v;
        }
      }
    }

    /* ===================== SEED PLAZA =============================== *
     * Pre-load a disc of wear so the hub is already forming. amount is the
     * peak wear at the center; it eases to 0 at radius. */
    function seedPlaza(worldX, worldZ, radius, amount) {
      if (amount == null) amount = PAVE_AT;
      var cx = gx(worldX), cz = gz(worldZ);
      var Rc = Math.max(1e-3, radius / Math.min(cellW, cellH)); // radius in cells
      var i0 = Math.floor(cx - Rc), i1 = Math.ceil(cx + Rc);
      var j0 = Math.floor(cz - Rc), j1 = Math.ceil(cz + Rc);
      i0 = i0 < 0 ? 0 : i0; j0 = j0 < 0 ? 0 : j0;
      i1 = i1 >= nx ? nx - 1 : i1; j1 = j1 >= nz ? nz - 1 : j1;

      for (var j = j0; j <= j1; j++) {
        var dz = (j - cz) / Rc;
        var row = j * nx;
        for (var i = i0; i <= i1; i++) {
          var dx = (i - cx) / Rc;
          var dist = Math.sqrt(dx * dx + dz * dz);
          if (dist > 1) continue;
          var w = amount * smoothstep(1, 0.25, dist); // full at center, 0 at edge
          var idx = row + i;
          if (w > wear[idx]) wear[idx] = w > WEAR_MAX ? WEAR_MAX : w;
        }
      }
      repaint(); // reflect the seed immediately
    }

    /* ===================== TEXTURE / CANVAS ========================= */
    var texW = Math.min(TEX_MAX, nx * TEX_OVERSAMPLE);
    var texH = Math.min(TEX_MAX, nz * TEX_OVERSAMPLE);
    var canvas = document.createElement('canvas');
    canvas.width = texW;
    canvas.height = texH;
    var ctx = canvas.getContext('2d');
    var imgData = ctx.createImageData(texW, texH);
    var pix = imgData.data; // reused every repaint

    var tex = new THREE.CanvasTexture(canvas);
    tex.wrapS = tex.wrapT = THREE.ClampToEdgeWrapping;
    tex.minFilter = THREE.LinearFilter;     // bilinear smoothing on downscale
    tex.magFilter = THREE.LinearFilter;     // bilinear smoothing -> soft edges
    tex.generateMipmaps = false;
    tex.encoding = THREE.sRGBEncoding;       // albedo is color data (r128 API)
    tex.anisotropy = 1;

    // ---- one box-blur pass over the wear field into blurBuf (read-only paint) ----
    var wearRead = wear; // default: paint reads the raw field
    function blurField() {
      for (var p = 0; p < GRID_BLUR_PASS; p++) {
        for (var j = 0; j < nz; j++) {
          for (var i = 0; i < nx; i++) {
            var s = 0, n = 0;
            for (var dj = -1; dj <= 1; dj++) {
              var jj = j + dj; if (jj < 0 || jj >= nz) continue;
              for (var di = -1; di <= 1; di++) {
                var ii = i + di; if (ii < 0 || ii >= nx) continue;
                s += wear[jj * nx + ii]; n++;
              }
            }
            blurBuf[j * nx + i] = s / n;
          }
        }
        // paint reads the blurred copy this frame; we never mutate `wear` here
        // (blurring the live field would permanently smear deposits).
        wearRead = blurBuf;
      }
    }

    // bilinear sample of the (possibly blurred) field at fractional cell coords
    function sampleField(field, fx, fz) {
      var x = clamp(fx, 0, nx - 1.0001);
      var z = clamp(fz, 0, nz - 1.0001);
      var i0 = x | 0, j0 = z | 0;
      var i1 = i0 + 1 < nx ? i0 + 1 : i0;
      var j1 = j0 + 1 < nz ? j0 + 1 : j0;
      var tx = x - i0, tz = z - j0;
      var a = field[j0 * nx + i0], b = field[j0 * nx + i1];
      var c = field[j1 * nx + i0], d = field[j1 * nx + i1];
      return lerp(lerp(a, b, tx), lerp(c, d, tx), tz);
    }

    var _col = [0, 0, 0];
    function repaint() {
      // produce wearRead (raw or blurred)
      if (GRID_BLUR_PASS > 0) blurField(); else wearRead = wear;
      var field = wearRead;

      var invW = (nx - 1) / (texW - 1 || 1);
      var invH = (nz - 1) / (texH - 1 || 1);

      var o = 0;
      for (var py = 0; py < texH; py++) {
        var fz = py * invH;
        for (var px = 0; px < texW; px++, o += 4) {
          var fx = px * invW;
          var w = sampleField(field, fx, fz);

          // ALPHA: soft threshold so faint wear is barely visible
          var a = smoothstep(ALPHA_KNEE, ALPHA_FULL, w) * ALPHA_CEIL;
          if (a <= 0.003) { pix[o + 3] = 0; continue; } // fully transparent: skip RGB

          // RGB: light brown -> packed earth -> deep brown
          if (w < BAND_EARTH) {
            lerp3(COL_DIRT, COL_EARTH, smoothstep(0, BAND_EARTH, w), _col);
          } else {
            lerp3(COL_EARTH, COL_COBBLE, smoothstep(BAND_EARTH, BAND_COBBLE, w), _col);
          }

          // per-cell noise -> earth grain, not a flat blob (strongest on deep paths)
          var cellI = (fx + 0.5) | 0, cellJ = (fz + 0.5) | 0;
          var n = (hash01(cellI, cellJ) - 0.5) * 2;           // [-1,1]
          var pathDepth = smoothstep(BAND_EARTH, BAND_COBBLE, w);
          var jit = 1 + n * NOISE_AMP * (0.4 + 0.6 * pathDepth);

          pix[o]     = clamp(_col[0] * jit, 0, 255);
          pix[o + 1] = clamp(_col[1] * jit, 0, 255);
          pix[o + 2] = clamp(_col[2] * jit, 0, 255);
          pix[o + 3] = clamp(a * 255, 0, 255);
        }
      }
      ctx.putImageData(imgData, 0, 0);
      tex.needsUpdate = true;
      wearRead = wear; // reset so deposits next frame read/write the live field
    }

    /* ======================= UPDATE (decay + throttled repaint) ===== */
    var repaintAccum = 0;
    var repaintInterval = 1 / REPAINT_HZ;
    function update(dt) {
      if (!(dt > 0)) dt = 0;
      // exponential decay, frame-rate independent
      var keep = Math.exp(-DECAY_RATE * dt);
      if (keep < 1) {
        for (var k = 0, n = wear.length; k < n; k++) {
          var v = wear[k] * keep;
          wear[k] = v < 1e-4 ? 0 : v; // snap tiny values to 0 (clean transparency)
        }
      }
      repaintAccum += dt;
      if (repaintAccum >= repaintInterval) {
        repaintAccum = 0;
        repaint();
      }
    }

    /* ======================= MESH =================================== */
    var geo = new THREE.PlaneGeometry(spanX, spanZ, 1, 1);
    var mat = new THREE.MeshStandardMaterial({
      map: tex,
      transparent: true,
      alphaTest: 0.01,            // discard fully-transparent texels cleanly
      depthWrite: false,          // thin decal over the desktop, never opaque
      roughness: 0.95,
      metalness: 0.0,
      side: THREE.FrontSide,
      polygonOffset: true,        // avoid z-fight with the shadow-catcher at y~0
      polygonOffsetFactor: -1,
      polygonOffsetUnits: -1
    });
    var mesh = new THREE.Mesh(geo, mat);
    mesh.rotation.x = -Math.PI / 2;                  // lay flat (XZ plane)
    mesh.position.set((minX + maxX) / 2, y, (minZ + maxZ) / 2);
    mesh.receiveShadow = true;
    mesh.renderOrder = 1;                             // composite after opaque scene
    mesh.frustumCulled = false;
    mesh.name = 'emergent-ground';

    // UV alignment (traced through the rotation): PlaneGeometry v=0 at local -Y,
    // v=1 at +Y. After rotation.x=-PI/2, local +Y -> world -Z. With default
    // flipY=true the mapping is correct and non-mirrored in both X and Z.
    tex.flipY = true;

    // first paint so the mesh isn't blank before the first update()
    repaint();

    /* ======================= DISPOSE =============================== */
    function dispose() {
      geo.dispose();
      mat.dispose();
      tex.dispose();
      wear = blurBuf = pix = imgData = null;
    }

    return {
      mesh: mesh,
      deposit: deposit,
      update: update,
      seedPlaza: seedPlaza,
      dispose: dispose,
      // exposed for debugging / tuning (not required by spec)
      _grid: { nx: nx, nz: nz, cellW: cellW, cellH: cellH }
    };
  };

  /* ##########################################################################
   * ##  PART 2 — TOWN ROUTING (agent behavior, no THREE dependency)         ##
   * ##  Drives gnomes between POIs and deposits wear under their feet so     ##
   * ##  emergent desire paths + a hub plaza form. Every emitted action is a  ##
   * ##  pose poseGnome() handles: walk|idle|build|cheer|carry|chat|forage    ##
   * ##  plus expedition poses such as grappleShoot|zipline|rappel|sample.    ##
   * ######################################################################## */

  window.createTownRouting = function createTownRouting(opts) {
    opts = opts || {};
    var bounds = opts.bounds || { minX: -100, maxX: 100, minZ: -100, maxZ: 100 };
    var polygon = (opts.polygon && opts.polygon.length >= 3) ? opts.polygon : null;
    var richBounds = {
      minX: bounds.minX,
      maxX: bounds.maxX,
      minZ: bounds.minZ,
      maxZ: bounds.maxZ,
      w: Math.max(0, bounds.maxX - bounds.minX),
      h: Math.max(0, bounds.maxZ - bounds.minZ)
    };
    var plaza = opts.plaza || {
      x: (bounds.minX + bounds.maxX) / 2,
      z: (bounds.minZ + bounds.maxZ) / 2
    };
    var homes = (opts.homes || []).slice();
    var works = (opts.works || []).slice();
    var wells = (opts.wells || []).slice();
    var plants = (opts.plantPOIs || []).slice();
    var expeditionPlants = (opts.expeditionPlants || []).slice();
    var butterflies = (opts.butterflyPOIs || []).slice();
    var tunnelLinks = (opts.tunnelLinks || []).slice();
    var explorationBounds = opts.explorationBounds || {
      minX: bounds.minX,
      maxX: bounds.maxX,
      minZ: bounds.minZ,
      maxZ: bounds.maxZ
    };

    /* ---- deterministic RNG (stable village across reloads) ---- */
    var rng = opts.rng || (function () {
      var s = 0x9e3779b9 >>> 0;
      return function () {
        s = (s + 0x6d2b79f5) >>> 0;
        var t = s;
        t = Math.imul(t ^ (t >>> 15), t | 1);
        t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
      };
    })();

    /* ---- tunables (world units / seconds) ------------------------------- */
    var SPAN = Math.max(1, Math.max(bounds.maxX - bounds.minX, bounds.maxZ - bounds.minZ));
    var ARRIVE = 9;                  // distance to a goal that counts as "arrived" (u)
    var DEPOSIT_BASE = 1.0;          // wear strength multiplier passed to deposit()
    var EDGE_PAD = 6;                // keep this far inside bounds
    var behaviorLiveliness = 1;
    var cooperationMultiplier = 1;
    var plantInteractionMultiplier = 1;
    var dailyRoutine = normalizedRoutingRoutine(opts.dailyRoutine);
    var SPEED = 22;
    var SPEED_JITTER = 0.22;
    var MEANDER_AMPL = Math.min(9, SPAN * 0.02);
    var MEANDER_FREQ = 0.94;
    var WAYPOINT_GRID = 7;
    var SAFE_SEGMENT_STEP = Math.max(2.5, Math.min(8, SPAN * 0.025));
    var BOUNDARY_PROBE = Math.max(EDGE_PAD * 1.45, Math.min(18, SPAN * 0.045));
    var STUCK_REPLAN_AT = 0.95;
    var PERSONAL_SPACE = Math.max(10, Math.min(18, SPAN * 0.052));
    var DWELL = {};
    var PLAZA_RELAY = {};
    var residents = [];
    var harvestMemory = {};

    function rand(a, b) { return a + (b - a) * rng(); }
    function pick(arr) { return arr[(rng() * arr.length) | 0]; }
    function clampN(v, lo, hi) { return v < lo ? lo : (v > hi ? hi : v); }
    function dist2(ax, az, bx, bz) { var dx = ax - bx, dz = az - bz; return dx * dx + dz * dz; }
    function normalizedRoutingSimulation(source) {
      source = source || {};
      return {
        behaviorLiveliness: clampN(Number(source.behaviorLiveliness || 1), 0.25, 2.5),
        cooperationMultiplier: clampN(Number(source.cooperationMultiplier || 1), 0, 2.5),
        plantInteractionMultiplier: clampN(Number(source.plantInteractionMultiplier || 1), 0, 2.5)
      };
    }
    function normalizedRoutingRoutine(source) {
      source = source || {};
      return {
        phase: String(source.phase || 'midday'),
        sleepBias: clampN(Number(source.sleepBias == null ? 0.12 : source.sleepBias), 0, 1),
        buildBias: clampN(Number(source.buildBias == null ? 0.55 : source.buildBias), 0, 1),
        socialBias: clampN(Number(source.socialBias == null ? 0.42 : source.socialBias), 0, 1),
        forageBias: clampN(Number(source.forageBias == null ? 0.42 : source.forageBias), 0, 1)
      };
    }
    function updateDailyRoutine(nextRoutine) {
      dailyRoutine = normalizedRoutingRoutine(nextRoutine);
      return dailyRoutine;
    }
    function updateTunnelLinks(nextLinks) {
      tunnelLinks = Array.isArray(nextLinks) ? nextLinks.slice() : [];
      return tunnelLinks;
    }
    /* Drop a gnome from this village's resident list — used when a tunnel courier
     * is handed off to a partner village so the source village's neighbor-
     * awareness loop stops tracking a gnome that no longer lives here. */
    function removeResident(gnome) {
      var idx = residents.indexOf(gnome);
      if (idx >= 0) residents.splice(idx, 1);
    }
    function updateSimulation(nextSimulation) {
      var sim = normalizedRoutingSimulation(nextSimulation);
      behaviorLiveliness = sim.behaviorLiveliness;
      cooperationMultiplier = sim.cooperationMultiplier;
      plantInteractionMultiplier = sim.plantInteractionMultiplier;
      SPEED = 22 * clampN(0.72 + behaviorLiveliness * 0.28, 0.45, 1.65);
      SPEED_JITTER = clampN(0.12 + behaviorLiveliness * 0.10, 0.12, 0.34);
      MEANDER_AMPL = Math.min(9, SPAN * (0.014 + behaviorLiveliness * 0.006));
      MEANDER_FREQ = 0.72 + behaviorLiveliness * 0.22;
      var dwellScale = clampN(1.22 - behaviorLiveliness * 0.18, 0.55, 1.25);
      DWELL = {
        idle: [2.0 * dwellScale, 5.0 * dwellScale],
        plaza: [3.0 * dwellScale, 7.5 * dwellScale],
        build: [3.5 * dwellScale, 6.5 * dwellScale],
        work: [3.0 * dwellScale, 5.5 * dwellScale],
        well: [1.5 * dwellScale, 3.0 * dwellScale],
        plant: [2.5 * dwellScale, 6.5 * dwellScale]
      };
      /* Plaza is THE social hub: a fraction of every non-plaza leg is routed
       * THROUGH the plaza as an intermediate waypoint. This is what makes
       * plaza<->everything routes dominate and the hub wear in. Tuned per role. */
      PLAZA_RELAY = {
        build: clampN(0.20 + cooperationMultiplier * 0.14, 0.05, 0.72),
        carry: clampN(0.24 + cooperationMultiplier * 0.16, 0.05, 0.82),
        idle: clampN(0.32 + cooperationMultiplier * 0.22, 0.05, 0.90)
      };
      return sim;
    }
    updateSimulation(opts.simulation);

    /* nearest home OTHER than the gnome's own — for "visit a neighbor" */
    function neighborHome(home) {
      if (homes.length <= 1) return null;
      var best = null, bd = Infinity;
      for (var i = 0; i < homes.length; i++) {
        if (homes[i] === home) continue;
        var d = dist2(homes[i].x, homes[i].z, home.x, home.z);
        if (d < bd) { bd = d; best = homes[i]; }
      }
      return best;
    }

    function pickPlantPOI() {
      if (!plants.length || plantInteractionMultiplier <= 0.001) return null;
      var total = 0;
      for (var i = 0; i < plants.length; i++) {
        total += Math.max(0.05, (plants[i].resourceValue || 0.25) * plantInteractionMultiplier);
      }
      var r = rng() * total;
      for (var j = 0; j < plants.length; j++) {
        r -= Math.max(0.05, (plants[j].resourceValue || 0.25) * plantInteractionMultiplier);
        if (r <= 0) return tag(plants[j], 'plant');
      }
      return tag(plants[plants.length - 1], 'plant');
    }

    function pickExpeditionPOI() {
      if (!expeditionPlants.length || plantInteractionMultiplier <= 0.001) return null;
      var total = 0;
      for (var i = 0; i < expeditionPlants.length; i++) {
        var plant = expeditionPlants[i];
        var heightBonus = plant.canClimb ? 0.34 : 0.12;
        total += Math.max(0.05, ((plant.resourceValue || 0.3) + (plant.canopyHeight || 0.1) + heightBonus) * harvestPressureFor(plant));
      }
      var r = rng() * total;
      for (var j = 0; j < expeditionPlants.length; j++) {
        var candidate = expeditionPlants[j];
        var score = Math.max(0.05, ((candidate.resourceValue || 0.3) + (candidate.canopyHeight || 0.1) + (candidate.canClimb ? 0.34 : 0.12)) * harvestPressureFor(candidate));
        r -= score;
        if (r <= 0) return tag(candidate, 'expeditionPlant');
      }
      return tag(expeditionPlants[expeditionPlants.length - 1], 'expeditionPlant');
    }

    function pickButterflyPOI() {
      if (!butterflies.length || plantInteractionMultiplier <= 0.001) return null;
      var daylight = 1 - dailyRoutine.sleepBias;
      if (daylight < 0.22) return null;
      var total = 0;
      for (var i = 0; i < butterflies.length; i++) {
        var b = butterflies[i];
        var plantBonus = b.plantTargets && b.plantTargets.length ? 0.18 : 0;
        total += Math.max(0.05, ((b.resourceValue || 0.38) + plantBonus) * daylight * plantInteractionMultiplier);
      }
      var r = rng() * total;
      for (var j = 0; j < butterflies.length; j++) {
        var candidate = butterflies[j];
        r -= Math.max(0.05, ((candidate.resourceValue || 0.38) + ((candidate.plantTargets && candidate.plantTargets.length) ? 0.18 : 0)) * daylight * plantInteractionMultiplier);
        if (r <= 0) return tag(candidate, 'butterfly');
      }
      return tag(butterflies[butterflies.length - 1], 'butterfly');
    }

    /* Pick a tunnel link to a partner zone, weighted toward NEARER partners
     * (shorter underground transit). Returns a POI tagged 'tunnelExit' that
     * walks the courier to THIS zone's tunnel entrance, carrying the link so the
     * arrival handler can start the dig sequence. */
    function pickTunnelExit(gnome) {
      if (!tunnelLinks.length) return null;
      var total = 0;
      for (var i = 0; i < tunnelLinks.length; i++) {
        var dist = Math.max(1, Number(tunnelLinks[i].distanceWorldUnits || 1));
        total += 1 / dist;   // nearer partners weighted higher
      }
      var r = rng() * total;
      var link = tunnelLinks[tunnelLinks.length - 1];
      for (var j = 0; j < tunnelLinks.length; j++) {
        r -= 1 / Math.max(1, Number(tunnelLinks[j].distanceWorldUnits || 1));
        if (r <= 0) { link = tunnelLinks[j]; break; }
      }
      var src = link.sourceEntrancePos || { x: gnome.x, z: gnome.z };
      return {
        x: src.x,
        z: src.z,
        kind: 'tunnelExit',
        tunnelLink: link,
        allowOutside: false
      };
    }

    function polygonContains(p) {
      return !polygon || typeof pointInPolygon !== 'function' || pointInPolygon(p.x, p.z, polygon);
    }

    function snapPointInsidePolygon(p) {
      if (polygonContains(p)) return p;
      if (polygon && typeof snapInside === 'function') {
        var snapped = snapInside({ x: p.x, z: p.z }, polygon, richBounds);
        if (!polygon || typeof pointInPolygon !== 'function' || pointInPolygon(snapped.x, snapped.z, polygon)) {
          return copyPoint(p, { x: snapped.x, z: snapped.z });
        }
      }
      if (polygon && typeof polygonCentroid === 'function') {
        var center = polygonCentroid(polygon);
        if (!polygon || typeof pointInPolygon !== 'function' || pointInPolygon(center.x, center.z, polygon)) {
          return copyPoint(p, { x: center.x, z: center.z });
        }
      }
      return p;
    }

    function clampExploration(p) {
      var pad = Math.max(8, Math.min(SPAN * 0.04, 30));
      return copyPoint(p, {
        x: clampN(p.x, explorationBounds.minX + pad, explorationBounds.maxX - pad),
        z: clampN(p.z, explorationBounds.minZ + pad, explorationBounds.maxZ - pad)
      });
    }

    function clampInside(p) {
      if (p.allowOutside) return clampExploration(p);
      var padX = Math.min(EDGE_PAD, Math.max(0, (bounds.maxX - bounds.minX) * 0.18));
      var padZ = Math.min(EDGE_PAD, Math.max(0, (bounds.maxZ - bounds.minZ) * 0.18));
      var rectClamped = {
        x: clampN(p.x, bounds.minX + padX, bounds.maxX - padX),
        z: clampN(p.z, bounds.minZ + padZ, bounds.maxZ - padZ),
        kind: p.kind,
        resourceValue: p.resourceValue,
        canClimb: p.canClimb,
        canopyHeight: p.canopyHeight,
        sampleColor: p.sampleColor,
        species: p.species,
        allowOutside: !!p.allowOutside,
        id: p.id,
        tunnelLink: p.tunnelLink
      };
      return snapPointInsidePolygon(rectClamped);
    }

    function movementClamp(gnome, p, target) {
      if ((target && target.allowOutside) || gnome.missionPhase === 'depart' || gnome.missionPhase === 'return' || gnome.missionPhase === 'rappelDown' || gnome.missionPhase === 'ziplineUp' || gnome.missionPhase === 'butterflySeek' || gnome.missionPhase === 'butterflyLaunch' || gnome.missionPhase === 'butterflyRide' || gnome.missionPhase === 'butterflyReturn') {
        return clampExploration(p);
      }
      return clampInside(p);
    }

    function candidateKey(p) {
      return Math.round(p.x * 10) + ':' + Math.round(p.z * 10);
    }

    function addCandidate(list, seen, p, kind) {
      if (!p) return;
      var candidate = copyPoint(p, { kind: kind || p.kind || 'waypoint' });
      if (candidate.allowOutside) return;
      candidate = clampInside(candidate);
      if (!polygonContains(candidate)) return;
      var key = candidateKey(candidate);
      if (seen[key]) return;
      seen[key] = true;
      list.push(candidate);
    }

    function interiorCenter() {
      if (polygon && typeof polygonCentroid === 'function') {
        return clampInside(tag(polygonCentroid(polygon), 'waypoint'));
      }
      return clampInside(tag(plaza, 'plaza'));
    }

    function routeCandidatePoints() {
      var points = [];
      var seen = {};
      var center = interiorCenter();
      addCandidate(points, seen, center, 'waypoint');
      addCandidate(points, seen, plazaPOI, 'plaza');

      for (var h = 0; h < homes.length; h++) addCandidate(points, seen, homes[h], 'home');
      for (var w = 0; w < works.length; w++) addCandidate(points, seen, works[w], 'work');
      for (var wl = 0; wl < wells.length; wl++) addCandidate(points, seen, wells[wl], 'well');
      for (var p = 0; p < plants.length; p++) addCandidate(points, seen, plants[p], 'plant');

      if (polygon && polygon.length) {
        for (var vi = 0; vi < polygon.length; vi++) {
          var vertex = polygon[vi];
          addCandidate(points, seen, {
            x: vertex.x * 0.72 + center.x * 0.28,
            z: vertex.z * 0.72 + center.z * 0.28
          }, 'turn');
          addCandidate(points, seen, {
            x: vertex.x * 0.54 + center.x * 0.46,
            z: vertex.z * 0.54 + center.z * 0.46
          }, 'turn');
        }
      }

      var stepX = richBounds.w / Math.max(1, WAYPOINT_GRID - 1);
      var stepZ = richBounds.h / Math.max(1, WAYPOINT_GRID - 1);
      for (var gx = 0; gx < WAYPOINT_GRID; gx++) {
        for (var gz = 0; gz < WAYPOINT_GRID; gz++) {
          var x = richBounds.minX + stepX * gx;
          var z = richBounds.minZ + stepZ * gz;
          addCandidate(points, seen, { x: x, z: z }, 'waypoint');
        }
      }
      return points;
    }

    function segmentInside(a, b) {
      if (!a || !b) return false;
      if (!polygon || a.allowOutside || b.allowOutside) return true;
      var dx = b.x - a.x;
      var dz = b.z - a.z;
      var len = Math.sqrt(dx * dx + dz * dz);
      var samples = Math.max(6, Math.ceil(len / SAFE_SEGMENT_STEP));
      var px = len > 0 ? -dz / len : 0;
      var pz = len > 0 ? dx / len : 0;
      var clearance = Math.max(1.8, Math.min(4.6, BOUNDARY_PROBE * 0.24));
      for (var i = 0; i <= samples; i++) {
        var t = i / samples;
        var sx = a.x + dx * t;
        var sz = a.z + dz * t;
        if (!polygonContains({ x: sx, z: sz })) return false;
        if (i > 0 && i < samples) {
          if (!polygonContains({ x: sx + px * clearance, z: sz + pz * clearance })) return false;
          if (!polygonContains({ x: sx - px * clearance, z: sz - pz * clearance })) return false;
        }
      }
      return true;
    }

    function routeCost(a, b) {
      var dx = b.x - a.x;
      var dz = b.z - a.z;
      var cost = Math.sqrt(dx * dx + dz * dz);
      if (b.kind === 'plaza') cost *= 0.92;
      if (b.kind === 'turn' || b.kind === 'waypoint') cost *= 1.04;
      return cost;
    }

    function planRoute(gnome, destination, preferredRelay) {
      var dest = destination && destination.allowOutside ? clampExploration(destination) : clampInside(destination || plazaPOI);
      if (dest.allowOutside) {
        return preferredRelay ? [clampInside(preferredRelay), dest] : [dest];
      }

      var start = clampInside({ x: gnome.x, z: gnome.z, kind: 'start' });
      var forcedRelay = preferredRelay ? clampInside(preferredRelay) : null;
      if (!forcedRelay && segmentInside(start, dest)) return [dest];
      if (forcedRelay && segmentInside(start, forcedRelay) && segmentInside(forcedRelay, dest)) {
        return [forcedRelay, dest];
      }

      var candidates = [];
      var seen = {};
      if (forcedRelay) addCandidate(candidates, seen, forcedRelay, forcedRelay.kind || 'plaza');
      var routed = routeCandidatePoints();
      for (var i = 0; i < routed.length; i++) addCandidate(candidates, seen, routed[i], routed[i].kind);
      addCandidate(candidates, seen, dest, dest.kind || 'goal');

      var nodes = [start].concat(candidates);
      var destKey = candidateKey(dest);
      var destIndex = -1;
      for (var di = 1; di < nodes.length; di++) {
        if (candidateKey(nodes[di]) === destKey) { destIndex = di; break; }
      }
      if (destIndex < 0) {
        nodes.push(dest);
        destIndex = nodes.length - 1;
      }

      var n = nodes.length;
      var dist = new Array(n);
      var prev = new Array(n);
      var used = new Array(n);
      for (var j = 0; j < n; j++) { dist[j] = Infinity; prev[j] = -1; used[j] = false; }
      dist[0] = 0;

      for (var pass = 0; pass < n; pass++) {
        var best = -1;
        var bestCost = Infinity;
        for (var ui = 0; ui < n; ui++) {
          if (!used[ui] && dist[ui] < bestCost) { bestCost = dist[ui]; best = ui; }
        }
        if (best < 0 || best === destIndex) break;
        used[best] = true;
        for (var ni = 1; ni < n; ni++) {
          if (used[ni] || ni === best) continue;
          if (!segmentInside(nodes[best], nodes[ni])) continue;
          var nextCost = dist[best] + routeCost(nodes[best], nodes[ni]);
          if (forcedRelay && candidateKey(nodes[ni]) === candidateKey(forcedRelay)) nextCost *= 0.82;
          if (nextCost < dist[ni]) {
            dist[ni] = nextCost;
            prev[ni] = best;
          }
        }
      }

      if (prev[destIndex] < 0 && !segmentInside(start, dest)) {
        var center = interiorCenter();
        if (segmentInside(start, center) && segmentInside(center, dest)) return [center, dest];
        if (forcedRelay) return [forcedRelay, dest];
        return [dest];
      }

      var route = [];
      var cursor = destIndex;
      while (cursor > 0) {
        route.unshift(nodes[cursor]);
        cursor = prev[cursor];
        if (cursor < 0) break;
      }
      return route.length ? route : [dest];
    }

    function boundaryPressureAt(x, z) {
      var pushX = 0;
      var pushZ = 0;
      var hits = 0;
      var dirs = [
        { x: 1, z: 0 }, { x: -1, z: 0 },
        { x: 0, z: 1 }, { x: 0, z: -1 },
        { x: 0.707, z: 0.707 }, { x: -0.707, z: 0.707 },
        { x: 0.707, z: -0.707 }, { x: -0.707, z: -0.707 }
      ];
      for (var i = 0; i < dirs.length; i++) {
        var probe = { x: x + dirs[i].x * BOUNDARY_PROBE, z: z + dirs[i].z * BOUNDARY_PROBE };
        if (!polygonContains(probe)) {
          pushX -= dirs[i].x;
          pushZ -= dirs[i].z;
          hits++;
        }
      }
      if (x < bounds.minX + EDGE_PAD * 1.8) { pushX += 1; hits++; }
      if (x > bounds.maxX - EDGE_PAD * 1.8) { pushX -= 1; hits++; }
      if (z < bounds.minZ + EDGE_PAD * 1.8) { pushZ += 1; hits++; }
      if (z > bounds.maxZ - EDGE_PAD * 1.8) { pushZ -= 1; hits++; }
      var mag = Math.sqrt(pushX * pushX + pushZ * pushZ);
      if (!mag) return { x: 0, z: 0, strength: 0 };
      return {
        x: pushX / mag,
        z: pushZ / mag,
        strength: clampN(hits / dirs.length, 0, 1)
      };
    }

    function angleDelta(a, b) {
      var d = a - b;
      while (d > Math.PI) d -= Math.PI * 2;
      while (d < -Math.PI) d += Math.PI * 2;
      return d;
    }

    function turnToward(current, desired, rate, dt) {
      var d = angleDelta(desired, current);
      var maxTurn = rate * dt;
      return current + clampN(d, -maxTurn, maxTurn);
    }

    function ensureMind(gnome) {
      if (!gnome.mind) {
        gnome.mind = {
          needs: {
            rest: rand(0.12, 0.46),
            social: rand(0.18, 0.62),
            purpose: rand(0.24, 0.74),
            curiosity: rand(0.15, 0.68),
            supplies: rand(0.10, 0.55)
          },
          intent: null,
          confidence: rand(0.58, 0.92),
          boundaryAwareness: 0,
          lastDecisionAt: gnome.missionClock || 0
        };
      }
      if (!gnome.mind.needs) gnome.mind.needs = {};
      return gnome.mind;
    }

    function updateMind(gnome, dt) {
      var mind = ensureMind(gnome);
      var n = mind.needs;
      n.rest = clampN((n.rest || 0) + dt * (0.003 + dailyRoutine.sleepBias * 0.006), 0, 1);
      n.social = clampN((n.social || 0) + dt * (0.004 + dailyRoutine.socialBias * 0.006), 0, 1);
      n.purpose = clampN((n.purpose || 0) + dt * (gnome.role === 'build' ? 0.010 : 0.005), 0, 1);
      n.curiosity = clampN((n.curiosity || 0) + dt * (0.004 + dailyRoutine.forageBias * 0.008), 0, 1);
      n.supplies = clampN((n.supplies || 0) + dt * (gnome.role === 'carry' ? 0.010 : 0.003), 0, 1);
      if (gnome.action === 'build') n.purpose = clampN(n.purpose - dt * 0.055, 0, 1);
      if (gnome.action === 'chat' || gnome.action === 'cheer') n.social = clampN(n.social - dt * 0.050, 0, 1);
      if (gnome.action === 'forage' || gnome.action === 'inspect' || gnome.action === 'sample' || gnome.action === 'canopyInspect' || gnome.action === 'extractTap' || gnome.action === 'sampleBundle' || gnome.action === 'catalogSample' || gnome.action === 'butterflyMount' || gnome.action === 'butterflyRide' || gnome.action === 'butterflyRelease') n.curiosity = clampN(n.curiosity - dt * 0.045, 0, 1);
      if (gnome.action === 'carry') n.supplies = clampN(n.supplies - dt * 0.025, 0, 1);
      if (gnome.restingInside || gnome.action === 'idle') n.rest = clampN(n.rest - dt * 0.018, 0, 1);
      return mind;
    }

    function intentFor(gnome, dest) {
      var kind = dest && dest.kind ? dest.kind : 'wander';
      var reason = 'checking the village';
      if (kind === 'work') reason = 'helping the build crew';
      else if (kind === 'well') reason = 'hauling supplies';
      else if (kind === 'plaza') reason = 'checking in with neighbors';
      else if (kind === 'plant' || kind === 'expeditionPlant') reason = 'studying nearby plants';
      else if (kind === 'butterfly') reason = 'asking a butterfly for a sky tour';
      else if (kind === 'home') reason = 'returning home';
      else if (kind === 'sampleDepot') reason = 'bringing samples back';
      return { kind: kind, reason: reason, since: gnome.missionClock || 0 };
    }

    function settleMindAt(gnome, kind) {
      var mind = ensureMind(gnome);
      var n = mind.needs;
      if (kind === 'home') n.rest = clampN(n.rest - 0.34, 0, 1);
      else if (kind === 'plaza') n.social = clampN(n.social - 0.38, 0, 1);
      else if (kind === 'work') n.purpose = clampN(n.purpose - 0.36, 0, 1);
      else if (kind === 'well') n.supplies = clampN(n.supplies - 0.32, 0, 1);
      else if (kind === 'plant' || kind === 'expeditionPlant') n.curiosity = clampN(n.curiosity - 0.30, 0, 1);
      else if (kind === 'butterfly') n.curiosity = clampN(n.curiosity - 0.42, 0, 1);
      mind.intent = { kind: kind || 'idle', reason: 'settling into the moment', since: gnome.missionClock || 0 };
    }

    function neighborAwareness(gnome) {
      var pushX = 0;
      var pushZ = 0;
      var strength = 0;
      var nearest = null;
      var nearestD2 = Infinity;
      for (var i = 0; i < residents.length; i++) {
        var other = residents[i];
        if (!other || other === gnome || other.restingInside) continue;
        var dx = gnome.x - other.x;
        var dz = gnome.z - other.z;
        var d2 = dx * dx + dz * dz;
        if (!isFinite(d2) || d2 <= 0.0001 || d2 > PERSONAL_SPACE * PERSONAL_SPACE) continue;
        if (d2 < nearestD2) { nearestD2 = d2; nearest = other; }
        var d = Math.sqrt(d2);
        var weight = 1 - d / PERSONAL_SPACE;
        pushX += (dx / d) * weight;
        pushZ += (dz / d) * weight;
        strength += weight;
      }
      var mag = Math.sqrt(pushX * pushX + pushZ * pushZ);
      return {
        x: mag > 0 ? pushX / mag : 0,
        z: mag > 0 ? pushZ / mag : 0,
        strength: clampN(strength, 0, 1),
        nearest: nearest,
        nearestDistance: nearest ? Math.sqrt(nearestD2) : Infinity
      };
    }

    function maybeSocialPause(gnome, awareness, dt) {
      if (!awareness || !awareness.nearest || awareness.nearestDistance > PERSONAL_SPACE * 0.68) return false;
      if (gnome.missionPhase || gnome.sampleCarried || gnome.dwell > 0) return false;
      var mind = ensureMind(gnome);
      var need = mind.needs ? (mind.needs.social || 0) : 0;
      var chance = dt * clampN((0.12 + need * 0.46 + dailyRoutine.socialBias * 0.30) * cooperationMultiplier, 0, 0.78);
      if (rng() > chance) return false;
      gnome.dwell = rand(0.9, 2.4);
      gnome.action = rng() < 0.22 ? 'cheer' : 'chat';
      mind.intent = { kind: 'social', reason: 'checking in with a neighbor', since: gnome.missionClock || 0 };
      mind.needs.social = clampN((mind.needs.social || 0) - 0.24, 0, 1);
      var other = awareness.nearest;
      if (other && !other.missionPhase && !other.sampleCarried && (other.dwell || 0) <= 0) {
        ensureMind(other).intent = { kind: 'social', reason: 'answering a neighbor', since: other.missionClock || 0 };
        other.dwell = rand(0.7, 1.8);
        other.action = 'chat';
      }
      return true;
    }

    /* tag a POI with a 'kind' so we can choose dwell action on arrival */
    function tag(p, kind) {
      return p ? {
        x: p.x,
        z: p.z,
        kind: kind,
        resourceValue: p.resourceValue,
        canClimb: p.canClimb,
        canopyHeight: p.canopyHeight,
        sampleColor: p.sampleColor,
        species: p.species,
        flightHeight: p.flightHeight,
        wingColor: p.wingColor,
        plantTargets: p.plantTargets ? p.plantTargets.slice() : null,
        circuitRadius: p.circuitRadius,
        allowOutside: !!p.allowOutside,
        id: p.id
      } : null;
    }
    function copyPoint(source, override) {
      var base = source || {};
      var next = override || {};
      return {
        x: next.x != null ? next.x : base.x,
        z: next.z != null ? next.z : base.z,
        kind: next.kind || base.kind,
        resourceValue: base.resourceValue,
        canClimb: base.canClimb,
        canopyHeight: base.canopyHeight,
        sampleColor: base.sampleColor,
        species: base.species,
        flightHeight: next.flightHeight != null ? next.flightHeight : base.flightHeight,
        wingColor: next.wingColor != null ? next.wingColor : base.wingColor,
        plantTargets: next.plantTargets ? next.plantTargets.slice() : (base.plantTargets ? base.plantTargets.slice() : null),
        circuitRadius: next.circuitRadius != null ? next.circuitRadius : base.circuitRadius,
        allowOutside: !!base.allowOutside,
        id: base.id,
        tunnelLink: base.tunnelLink
      };
    }

    var plazaPOI = tag(plaza, 'plaza');

    /* ---------------------------------------------------------------------
     * assign: give a gnome a home + role-appropriate starting goal.
     * ------------------------------------------------------------------- */
    function assign(gnome) {
      if (!gnome.role) gnome.role = pick(['build', 'carry', 'idle']);
      // normalize legacy/UI roles to the three behavior roles
      if (gnome.role !== 'build' && gnome.role !== 'carry') gnome.role = 'idle';

      gnome.home = gnome.home || (homes.length ? pick(homes) : plaza);
      if (gnome.role === 'build') gnome.work = gnome.work || (works.length ? pick(works) : plaza);

      gnome.speed = (gnome.speed || 1) * rand(1 - SPEED_JITTER, 1 + SPEED_JITTER);

      // start where the gnome currently stands (caller mirrors group.position),
      // else park at home, then immediately route somewhere meaningful.
      if (gnome.x === undefined) { gnome.x = gnome.home.x; gnome.z = gnome.home.z; }
      var insideStart = clampInside({ x: gnome.x, z: gnome.z });
      gnome.x = insideStart.x;
      gnome.z = insideStart.z;
      gnome.goal = null;
      gnome.dwell = 0;
      gnome.restingInside = false;
      gnome.missionClock = gnome.missionClock || rand(0, 18);
      gnome.nextMissionAt = gnome.nextMissionAt || rand(18, 75);
      gnome.nextButterflyRideAt = gnome.nextButterflyRideAt || rand(35, 140);
      gnome.missionPhase = null;
      gnome.missionTarget = null;
      gnome.tunnelPhase = null;
      gnome.tunnelLink = null;
      gnome.tunnelProgress = 0;
      gnome.tunnelEmergeProgress = 0;
      gnome.sampleCarried = false;
      gnome.deliveredSamples = gnome.deliveredSamples || 0;
      gnome.relay = null;          // optional plaza waypoint between current pos and goal
      gnome.route = null;          // planned interior waypoints through concave village zones
      gnome.routeIndex = 0;
      gnome.stuckScore = 0;
      gnome.legPhase = rng() * Math.PI * 2;  // meander seed
      gnome.heading = (gnome.heading != null) ? gnome.heading : 0;
      gnome.action = 'idle';
      ensureMind(gnome);
      if (residents.indexOf(gnome) < 0) residents.push(gnome);
      pickGoal(gnome);
      return gnome;
    }

    function maybeChooseButterflyRide(gnome) {
      if (gnome.tunnelCourier) return null;   // couriers stick to tunneling
      if (!butterflies.length || dailyRoutine.sleepBias > 0.70 || plantInteractionMultiplier <= 0.001) return null;
      if (gnome.sampleCarried || gnome.missionPhase) return null;
      if ((gnome.missionClock || 0) < (gnome.nextButterflyRideAt || 0)) return null;
      var mind = ensureMind(gnome);
      var curiosityNeed = mind.needs ? (mind.needs.curiosity || 0) : 0.35;
      var roleBonus = gnome.butterflyRider ? 0.18 : (gnome.role === 'idle' ? 0.08 : (gnome.role === 'carry' ? 0.04 : 0.02));
      var daylight = 1 - dailyRoutine.sleepBias;
      var chance = clampN((0.035 + curiosityNeed * 0.12 + dailyRoutine.forageBias * 0.08 + roleBonus) * daylight * plantInteractionMultiplier, 0.015, 0.34);
      if (rng() > chance) {
        gnome.nextButterflyRideAt = (gnome.missionClock || 0) + rand(55, 160);
        return null;
      }
      var target = pickButterflyPOI();
      if (!target) {
        gnome.nextButterflyRideAt = (gnome.missionClock || 0) + rand(75, 190);
        return null;
      }
      target.allowOutside = true;
      gnome.missionPhase = 'butterflySeek';
      gnome.missionTarget = target;
      gnome.butterflyRideTarget = target;
      gnome.nextButterflyRideAt = (gnome.missionClock || 0) + rand(210, 520);
      mind.intent = {
        kind: 'butterfly',
        reason: 'coaxing a butterfly into a tiny aerial survey',
        since: gnome.missionClock || 0
      };
      return target;
    }

    function maybeChooseExpedition(gnome) {
      if (gnome.tunnelCourier) return null;   // couriers stick to tunneling
      if (!expeditionPlants.length || dailyRoutine.sleepBias > 0.68 || plantInteractionMultiplier <= 0.001) return null;
      if (gnome.sampleCarried || gnome.missionPhase) return null;
      if ((gnome.missionClock || 0) < (gnome.nextMissionAt || 0)) return null;
      var daylight = 1 - dailyRoutine.sleepBias;
      var curiosity = plantInteractionMultiplier * (0.10 + dailyRoutine.forageBias * 0.22) * daylight;
      var specialist = gnome.expeditionSpecialist ? 0.34 : 0;
      if (rng() > clampN(curiosity + specialist, 0.08, 0.72)) {
        gnome.nextMissionAt = (gnome.missionClock || 0) + rand(28, 95);
        return null;
      }
      var target = pickExpeditionPOI();
      if (!target) return null;
      target.allowOutside = true;
      gnome.missionPhase = 'depart';
      gnome.missionTarget = target;
      return target;
    }

    function easeInOut(u) {
      u = clampN(u, 0, 1);
      return u * u * (3 - 2 * u);
    }

    function mix(a, b, u) {
      return a + (b - a) * u;
    }

    function harvestPressureFor(target) {
      var id = target && target.id ? String(target.id) : 'plant';
      var memory = harvestMemory[id];
      if (!memory) return 1;
      var age = Math.max(0, (residents[0] && residents[0].missionClock || 0) - (memory.lastAt || 0));
      var recentPenalty = age < 180 ? (1 - age / 180) * 0.55 : 0;
      var repeatPenalty = clampN((memory.count || 0) * 0.035, 0, 0.25);
      return clampN(1 - recentPenalty - repeatPenalty, 0.18, 1);
    }

    function recordHarvest(gnome) {
      var target = gnome && gnome.missionTarget;
      var id = target && target.id ? String(target.id) : null;
      if (!id) return;
      var memory = harvestMemory[id] || { count: 0, lastAt: 0, yield: 0 };
      memory.count += 1;
      memory.lastAt = gnome.missionClock || 0;
      memory.yield += Math.max(1, gnome.sampleYield || 1);
      harvestMemory[id] = memory;
    }

    function resourceCollectionPlanFor(target) {
      target = target || {};
      var species = String(target.species || target.id || '').toLowerCase();
      var plan = {
        method: 'leafClipping',
        tool: 'snips',
        resourceName: 'leaf cutting',
        color: target.sampleColor || 0x65b86f
      };
      if (species.indexOf('moss') >= 0 || species.indexOf('fern') >= 0 || species.indexOf('staghorn') >= 0) {
        plan.method = 'sporeBrush';
        plan.tool = 'brush';
        plan.resourceName = 'spore dust';
      } else if (species.indexOf('flower') >= 0 || species.indexOf('orchid') >= 0 || species.indexOf('cosmos') >= 0 || species.indexOf('night') >= 0) {
        plan.method = 'pollenBrush';
        plan.tool = 'brush';
        plan.resourceName = 'pollen sample';
      } else if (species.indexOf('tomato') >= 0 || species.indexOf('pepper') >= 0 || species.indexOf('fruit') >= 0 || species.indexOf('berry') >= 0 || species.indexOf('corn') >= 0) {
        plan.method = 'seedPod';
        plan.tool = 'vial';
        plan.resourceName = 'seed pod';
      } else if (species.indexOf('tree') >= 0 || species.indexOf('maple') >= 0 || species.indexOf('blood') >= 0 || species.indexOf('baobab') >= 0 || species.indexOf('eucalyptus') >= 0) {
        plan.method = 'barkTap';
        plan.tool = 'tap';
        plan.resourceName = 'bark resin';
      }
      return plan;
    }

    function beginCollectionSequence(gnome, target, elevated) {
      target = target || gnome.missionTarget || gnome.goal || plazaPOI;
      gnome.missionTarget = target;
      gnome.resourceCollectionPlan = resourceCollectionPlanFor(target);
      gnome.resourceCollectionElevated = !!elevated;
      var anchor = gnome.grappleAnchor || grappleAnchorFor(target);
      var resourceValue = clampN(Number(target.resourceValue || 0.35), 0, 1);
      var canopy = clampN(Number(target.canopyHeight || 0.12), 0, 0.5);
      gnome.sampleYield = Math.max(1, Math.min(3, Math.round(1 + resourceValue * 1.1 + canopy * 1.6)));
      gnome.resourceCollectionWorkPoint = elevated
        ? { x: anchor.x, z: anchor.z, y: Math.max(14, anchor.y - 10) }
        : { x: target.x, z: target.z, y: 12 + clampN(Number(target.canopyHeight || 0.12), 0.05, 0.35) * 85 };
      gnome.resourceCollectionProgress = 0;
      gnome.resourceCollectionStageProgress = 0;
      gnome.resourceCollectionStageDuration = rand(elevated ? 0.9 : 0.75, elevated ? 1.7 : 1.35);
      gnome.sampleCarried = false;
      gnome.missionPhase = elevated ? 'canopyInspect' : 'fieldInspect';
      gnome.action = elevated ? 'canopyInspect' : 'inspect';
      gnome.dwell = gnome.resourceCollectionStageDuration;
      ensureMind(gnome).intent = {
        kind: 'collect',
        reason: 'examining ' + gnome.resourceCollectionPlan.resourceName,
        since: gnome.missionClock || 0
      };
    }

    function advanceCollectionSequence(gnome) {
      if (gnome.missionPhase === 'canopyInspect' || gnome.missionPhase === 'fieldInspect') {
        gnome.missionPhase = 'extractTap';
        gnome.action = 'extractTap';
        gnome.resourceCollectionStageDuration = rand(1.4, 2.5);
        gnome.dwell = gnome.resourceCollectionStageDuration;
        gnome.resourceCollectionStageProgress = 0;
        gnome.resourceCollectionProgress = 0.34;
        ensureMind(gnome).intent = {
          kind: 'collect',
          reason: 'carefully extracting ' + ((gnome.resourceCollectionPlan && gnome.resourceCollectionPlan.resourceName) || 'a plant sample'),
          since: gnome.missionClock || 0
        };
        return true;
      }
      if (gnome.missionPhase === 'extractTap') {
        gnome.missionPhase = 'sampleBundle';
        gnome.action = 'sampleBundle';
        gnome.resourceCollectionStageDuration = rand(0.95, 1.85);
        gnome.dwell = gnome.resourceCollectionStageDuration;
        gnome.resourceCollectionStageProgress = 0;
        gnome.resourceCollectionProgress = 0.74;
        return true;
      }
      if (gnome.missionPhase === 'sampleBundle') {
        gnome.resourceCollectionStageProgress = 1;
        gnome.resourceCollectionProgress = 1;
        recordHarvest(gnome);
        if (gnome.grappleAnchor) {
          gnome.missionPhase = 'rappelDown';
          gnome.grappleProgress = 0;
          gnome.grappleTension = 1;
          gnome.dwell = 0;
          gnome.action = 'rappel';
        } else {
          beginReturnWithSample(gnome);
        }
        return true;
      }
      return false;
    }

    function grappleAnchorFor(target) {
      target = target || plazaPOI;
      var canopy = clampN(Number(target.canopyHeight || 0.18), 0.08, 0.5);
      return {
        x: target.x,
        z: target.z,
        y: 36 + canopy * 235,
        sampleColor: target.sampleColor,
        id: target.id
      };
    }

    function beginGrappleSequence(gnome, target) {
      target = target || gnome.goal || gnome.missionTarget || plazaPOI;
      gnome.missionTarget = target;
      gnome.missionPhase = 'grappleAim';
      gnome.action = 'grappleAim';
      gnome.dwell = rand(0.75, 1.25);
      gnome.grappleAnchor = grappleAnchorFor(target);
      gnome.grappleOrigin = {
        x: gnome.x,
        z: gnome.z,
        y: 11.5 + rand(0.2, 1.4)
      };
      gnome.grappleProgress = 0;
      gnome.grappleShootProgress = 0;
      gnome.grappleTension = 0;
      gnome.grappleLineJitter = rand(-1, 1);
      gnome.canopyFacing = null;
      gnome.ziplineHeight = 0;
      gnome.ziplineSpeed = rand(0.42, 0.64) * clampN(0.76 + behaviorLiveliness * 0.24, 0.7, 1.45);
      gnome.rappelSpeed = rand(0.52, 0.80) * clampN(0.72 + behaviorLiveliness * 0.22, 0.65, 1.35);
      ensureMind(gnome).intent = {
        kind: 'grapple',
        reason: 'setting a grappling hook for a plant expedition',
        since: gnome.missionClock || 0
      };
      return gnome.grappleAnchor;
    }

    /* Tunnel travel between two user-drawn zones. Mirrors beginGrappleSequence:
     * sets the mission phase + per-phase durations, then stepTunnelSequence and
     * the renderer's updateTunnelVisuals drive the dig/transit/emerge beats.
     * The actual cross-village hand-off happens in main.js once the gnome reaches
     * the 'tunnelArrived' phase (we can't reparent the gnome from in here). */
    function beginTunnelSequence(gnome, link) {
      if (!link) return false;
      gnome.tunnelLink = link;
      gnome.missionTarget = null;
      gnome.missionPhase = 'tunnelDigIn';
      gnome.tunnelPhase = 'tunnelDigIn';
      gnome.tunnelProgress = 0;
      gnome.tunnelDigDuration = rand(1.4, 2.2);
      gnome.tunnelTransitDuration = clampN(2.5 + Number(link.distanceWorldUnits || 0) * 0.008, 2.8, 8);
      gnome.tunnelEmergeDuration = rand(1.2, 2.0);
      gnome.dwell = gnome.tunnelDigDuration;
      gnome.action = 'tunnelDig';
      gnome.ziplineHeight = 0;
      ensureMind(gnome).intent = {
        kind: 'tunnel',
        reason: 'digging a tunnel to a neighboring colony',
        since: gnome.missionClock || 0
      };
      return true;
    }

    function beginReturnWithSample(gnome) {
      gnome.sampleCarried = true;
      gnome.resourceCollectionProgress = 1;
      gnome.missionPhase = 'return';
      gnome.grappleProgress = 1;
      gnome.grappleTension = 0.15;
      gnome.ziplineHeight = 0;
      gnome.goal = tag(plaza, 'sampleDepot');
      gnome.relay = null;
      gnome.route = planRoute(gnome, gnome.goal, null);
      gnome.routeIndex = 0;
      ensureMind(gnome).intent = intentFor(gnome, gnome.goal);
      gnome.legStartX = gnome.x;
      gnome.legStartZ = gnome.z;
      gnome.legPhase += rand(0.4, 1.8);
      gnome.action = 'carry';
    }

    function flightPoint(source, fallbackY) {
      source = source || {};
      return {
        x: Number(source.x || 0),
        y: Number(source.y != null ? source.y : fallbackY),
        z: Number(source.z || 0),
        behind: !!source.behind
      };
    }

    function butterflyFlightPlanFor(gnome, target) {
      target = target || {};
      var center = { x: target.x || gnome.x || plaza.x, z: target.z || gnome.z || plaza.z };
      var baseHeight = clampN(Number(target.flightHeight || 54), 28, 130);
      var radius = clampN(Number(target.circuitRadius || 34), 18, 82);
      var sourcePlants = (target.plantTargets || []).concat(expeditionPlants).concat(plants)
        .filter(function (p) { return p && isFinite(p.x) && isFinite(p.z); });
      var unique = [];
      var seen = {};
      for (var i = 0; i < sourcePlants.length; i++) {
        var p = sourcePlants[i];
        var key = String(p.id || Math.round(p.x) + ':' + Math.round(p.z));
        if (seen[key]) continue;
        seen[key] = true;
        unique.push(p);
        if (unique.length >= 4) break;
      }
      var points = [
        flightPoint({ x: center.x, y: baseHeight * 0.72, z: center.z }, baseHeight)
      ];
      if (!unique.length) {
        for (var f = 0; f < 6; f++) {
          var a = f * Math.PI * 2 / 6 + (gnome.legPhase || 0);
          points.push(flightPoint({
            x: center.x + Math.cos(a) * radius,
            y: baseHeight + Math.sin(f * 1.7) * 10,
            z: center.z + Math.sin(a) * radius * 0.62,
            behind: f % 2 === 1
          }, baseHeight));
        }
      } else {
        for (var j = 0; j < unique.length; j++) {
          var plant = unique[j];
          var canopy = clampN(Number(plant.canopyHeight || 0.16), 0.05, 0.5);
          var orbitRadius = radius * (0.70 + clampN(Number(plant.resourceValue || 0.35), 0, 1) * 0.55);
          for (var k = 0; k < 3; k++) {
            var angle = (j * 1.93 + k * 2.08 + (gnome.legPhase || 0)) % (Math.PI * 2);
            points.push(flightPoint({
              x: plant.x + Math.cos(angle) * orbitRadius,
              y: baseHeight + canopy * 120 + Math.sin(k * 1.4 + j) * 11,
              z: plant.z + Math.sin(angle) * orbitRadius * 0.58,
              behind: k === 1
            }, baseHeight));
          }
        }
      }
      points.push(flightPoint({ x: plaza.x, y: Math.max(26, baseHeight * 0.52), z: plaza.z, behind: false }, baseHeight));
      return {
        points: points,
        duration: rand(9.5, 18.0) * clampN(1.18 - behaviorLiveliness * 0.08, 0.75, 1.25),
        baseHeight: baseHeight,
        wingColor: target.wingColor || 0xffcf75
      };
    }

    function catmull(p0, p1, p2, p3, u, key) {
      var u2 = u * u;
      var u3 = u2 * u;
      return 0.5 * (
        (2 * p1[key]) +
        (-p0[key] + p2[key]) * u +
        (2 * p0[key] - 5 * p1[key] + 4 * p2[key] - p3[key]) * u2 +
        (-p0[key] + 3 * p1[key] - 3 * p2[key] + p3[key]) * u3
      );
    }

    function sampleFlightPlan(plan, progress) {
      var points = (plan && plan.points) || [];
      if (points.length < 2) return flightPoint(plaza, 0);
      var span = points.length - 1;
      var scaled = clampN(progress, 0, 1) * span;
      var i = Math.min(points.length - 2, Math.max(0, Math.floor(scaled)));
      var u = scaled - i;
      var p0 = points[Math.max(0, i - 1)];
      var p1 = points[i];
      var p2 = points[Math.min(points.length - 1, i + 1)];
      var p3 = points[Math.min(points.length - 1, i + 2)];
      return {
        x: catmull(p0, p1, p2, p3, u, 'x'),
        y: catmull(p0, p1, p2, p3, u, 'y'),
        z: catmull(p0, p1, p2, p3, u, 'z'),
        behind: !!(u < 0.55 ? p1.behind : p2.behind)
      };
    }

    function beginButterflyRideSequence(gnome, target) {
      target = target || gnome.goal || gnome.missionTarget || pickButterflyPOI();
      if (!target) return false;
      target.allowOutside = true;
      gnome.missionTarget = target;
      gnome.butterflyRideTarget = target;
      // Most flying mounts are dragonflies now; keep occasional butterflies for variety.
      gnome.mountType = rand(0, 1) < 0.72 ? 'dragonfly' : 'butterfly';
      gnome.butterflyFlightPlan = butterflyFlightPlanFor(gnome, target);
      gnome.butterflyLaunchOrigin = { x: gnome.x, y: 0, z: gnome.z };
      gnome.butterflyRideProgress = 0;
      gnome.butterflyRideDuration = gnome.butterflyFlightPlan.duration;
      gnome.butterflyPhaseSeed = rand(0, Math.PI * 2);
      gnome.butterflyBank = 0;
      gnome.butterflyDepthCue = 0;
      gnome.ziplineHeight = 0;
      gnome.missionPhase = 'butterflyMount';
      gnome.action = 'butterflyMount';
      gnome.dwell = rand(0.75, 1.35);
      ensureMind(gnome).intent = {
        kind: 'butterflyRide',
        reason: 'fastening a little saddle and asking for a sky loop',
        since: gnome.missionClock || 0
      };
      return true;
    }

    function finishButterflyRide(gnome) {
      gnome.missionPhase = 'butterflyRelease';
      gnome.action = 'butterflyRelease';
      gnome.dwell = rand(0.75, 1.55);
      gnome.ziplineHeight = 0;
      gnome.butterflyRideProgress = 1;
      ensureMind(gnome).intent = {
        kind: 'butterflyRelease',
        reason: 'thanking the butterfly and letting it drift away',
        since: gnome.missionClock || 0
      };
    }

    function clearButterflyRide(gnome) {
      gnome.missionPhase = null;
      gnome.missionTarget = null;
      gnome.butterflyRideTarget = null;
      gnome.butterflyFlightPlan = null;
      gnome.butterflyLaunchOrigin = null;
      gnome.butterflyReturnOrigin = null;
      gnome.butterflyRideProgress = 0;
      gnome.butterflyBank = 0;
      gnome.butterflyDepthCue = 0;
      gnome.ziplineHeight = 0;
    }

    function stepButterflyRideSequence(gnome, dt) {
      if (!gnome || !gnome.missionPhase) return false;
      var phase = gnome.missionPhase;
      if (phase !== 'butterflyLaunch' && phase !== 'butterflyRide' && phase !== 'butterflyReturn') return false;
      var plan = gnome.butterflyFlightPlan || butterflyFlightPlanFor(gnome, gnome.butterflyRideTarget || gnome.missionTarget);
      gnome.butterflyFlightPlan = plan;

      if (phase === 'butterflyLaunch') {
        var lp = clampN((gnome.butterflyRideProgress || 0) + dt * 0.78, 0, 1);
        var start = gnome.butterflyLaunchOrigin || { x: gnome.x, y: 0, z: gnome.z };
        var liftTarget = plan.points[0] || { x: gnome.x, y: 30, z: gnome.z };
        var lu = easeInOut(lp);
        gnome.x = mix(start.x, liftTarget.x, lu);
        gnome.z = mix(start.z, liftTarget.z, lu);
        gnome.ziplineHeight = mix(start.y || 0, liftTarget.y, lu) + Math.sin(lp * Math.PI) * 7;
        gnome.butterflyBank = Math.sin(lp * Math.PI * 2 + (gnome.butterflyPhaseSeed || 0)) * 0.12;
        gnome.butterflyDepthCue = 0;
        gnome.heading = turnToward(gnome.heading || 0, Math.atan2(liftTarget.x - start.x, liftTarget.z - start.z), 4.8, dt);
        gnome.action = 'butterflyRide';
        gnome.butterflyRideProgress = lp;
        if (lp >= 1) {
          gnome.missionPhase = 'butterflyRide';
          gnome.butterflyRideProgress = 0;
        }
        return true;
      }

      if (phase === 'butterflyRide') {
        var rp = clampN((gnome.butterflyRideProgress || 0) + dt / Math.max(1.0, gnome.butterflyRideDuration || 12), 0, 1);
        var here = sampleFlightPlan(plan, rp);
        var ahead = sampleFlightPlan(plan, clampN(rp + 0.018, 0, 1));
        gnome.x = here.x;
        gnome.z = here.z;
        gnome.ziplineHeight = Math.max(18, here.y + Math.sin((gnome.missionClock || 0) * 2.8 + (gnome.butterflyPhaseSeed || 0)) * 2.4);
        gnome.heading = turnToward(gnome.heading || 0, Math.atan2(ahead.x - here.x, ahead.z - here.z), 5.6, dt);
        gnome.butterflyBank = clampN(angleDelta(Math.atan2(ahead.x - here.x, ahead.z - here.z), gnome.heading || 0) * 0.75 + Math.sin(rp * Math.PI * 8 + (gnome.butterflyPhaseSeed || 0)) * 0.08, -0.42, 0.42);
        gnome.butterflyDepthCue = here.behind ? -1 : 1;
        gnome.action = 'butterflyRide';
        gnome.butterflyRideProgress = rp;
        if (rp >= 1) {
          gnome.missionPhase = 'butterflyReturn';
          gnome.butterflyReturnOrigin = { x: gnome.x, y: gnome.ziplineHeight, z: gnome.z };
          gnome.butterflyRideProgress = 0;
        }
        return true;
      }

      var tp = clampN((gnome.butterflyRideProgress || 0) + dt * 0.52, 0, 1);
      var origin = gnome.butterflyReturnOrigin || { x: gnome.x, y: gnome.ziplineHeight || 30, z: gnome.z };
      var tu = easeInOut(tp);
      gnome.x = mix(origin.x, plaza.x, tu);
      gnome.z = mix(origin.z, plaza.z, tu);
      gnome.ziplineHeight = Math.max(0, mix(origin.y, 0, tu) + Math.sin(tp * Math.PI) * 9);
      gnome.heading = turnToward(gnome.heading || 0, Math.atan2(plaza.x - origin.x, plaza.z - origin.z), 5.2, dt);
      gnome.butterflyBank = Math.sin(tp * Math.PI * 2 + (gnome.butterflyPhaseSeed || 0)) * 0.10;
      gnome.butterflyDepthCue = 0;
      gnome.action = 'butterflyRide';
      gnome.butterflyRideProgress = tp;
      if (tp >= 1) {
        gnome.x = plaza.x;
        gnome.z = plaza.z;
        finishButterflyRide(gnome);
      }
      return true;
    }

    /* Progress-driven half of the tunnel sequence (the dwell-driven dig-in and
     * emerge beats are advanced in the dwelling block, mirroring how grappleAim/
     * grappleShoot dwell while ziplineUp/rappelDown step here). Only the
     * 'tunnelUnderground' transit is handled here: the gnome is invisible and we
     * march tunnelProgress 0->1, then surface it at the partner zone's entrance.
     * The cross-village reparent itself happens in main.js at 'tunnelArrived'. */
    function stepTunnelSequence(gnome, dt) {
      if (!gnome || gnome.tunnelPhase !== 'tunnelUnderground') return false;
      var link = gnome.tunnelLink || {};
      gnome.tunnelProgress = clampN((gnome.tunnelProgress || 0) + dt / Math.max(0.5, gnome.tunnelTransitDuration || 4), 0, 1);
      // stays invisible + grounded; no wear deposited while underground.
      if (gnome.group) gnome.group.visible = false;
      gnome.ziplineHeight = 0;
      if (gnome.tunnelProgress >= 1) {
        var dest = link.targetEntrancePos || { x: gnome.x, z: gnome.z };
        gnome.x = dest.x;
        gnome.z = dest.z;
        if (gnome.group) gnome.group.visible = true;
        gnome.tunnelPhase = 'tunnelEmerge';
        gnome.missionPhase = 'tunnelEmerge';
        gnome.tunnelEmergeProgress = 0;
        gnome.dwell = gnome.tunnelEmergeDuration || rand(1.2, 2.0);
        gnome.action = 'tunnelEmerge';
        // face roughly toward the new plaza so the emerge reads naturally
        gnome.heading = Math.atan2(plaza.x - gnome.x, plaza.z - gnome.z);
      }
      return true;
    }

    function stepGrappleSequence(gnome, dt) {
      if (!gnome || !gnome.missionPhase) return false;
      var phase = gnome.missionPhase;
      if (phase !== 'ziplineUp' && phase !== 'rappelDown') return false;
      var anchor = gnome.grappleAnchor || grappleAnchorFor(gnome.missionTarget || gnome.goal);
      var origin = gnome.grappleOrigin || { x: gnome.x, z: gnome.z, y: 12 };
      var progress = clampN((gnome.grappleProgress || 0) + dt * (phase === 'ziplineUp' ? (gnome.ziplineSpeed || 0.5) : (gnome.rappelSpeed || 0.66)), 0, 1);
      var eased = easeInOut(progress);

      if (phase === 'ziplineUp') {
        gnome.x = mix(origin.x, anchor.x, eased);
        gnome.z = mix(origin.z, anchor.z, eased);
        gnome.ziplineHeight = mix(origin.y, Math.max(12, anchor.y - 17), eased) + Math.sin(progress * Math.PI) * 5.2;
        gnome.grappleTension = clampN(0.45 + progress * 0.55, 0, 1);
        // Hold a steady facing while climbing. When the rope is near-vertical
        // (gnome almost directly under the anchor) the horizontal heading is
        // degenerate, so keep the arrival heading instead of snapping around.
        var horizSpan = Math.hypot(anchor.x - origin.x, anchor.z - origin.z);
        var climbDir = horizSpan > 4 ? Math.atan2(anchor.x - origin.x, anchor.z - origin.z)
          : (gnome.heading != null ? gnome.heading : 0);
        gnome.heading = turnToward(gnome.heading != null ? gnome.heading : climbDir, climbDir, 3.4, dt);
        gnome.action = 'zipline';
        gnome.grappleProgress = progress;
        if (progress >= 1) {
          gnome.x = anchor.x;
          gnome.z = anchor.z;
          gnome.ziplineHeight = Math.max(12, anchor.y - 17);
          beginCollectionSequence(gnome, gnome.missionTarget || gnome.goal, true);
        }
        return true;
      }

      gnome.x = anchor.x + Math.sin(progress * Math.PI) * 1.1 * (gnome.grappleLineJitter || 0);
      gnome.z = anchor.z + Math.cos(progress * Math.PI) * 0.8 * (gnome.grappleLineJitter || 0);
      gnome.ziplineHeight = mix(Math.max(12, anchor.y - 17), 0, eased);
      gnome.grappleTension = clampN(1 - progress * 0.68, 0, 1);
      gnome.heading = turnToward(gnome.heading || 0, Math.atan2(plaza.x - gnome.x, plaza.z - gnome.z), 4.8, dt);
      gnome.action = 'rappel';
      gnome.grappleProgress = progress;
      if (progress >= 1) {
        gnome.x = anchor.x;
        gnome.z = anchor.z;
        beginReturnWithSample(gnome);
      }
      return true;
    }

    /* ---------------------------------------------------------------------
     * Goal selection — weighted by role. Returns a tagged POI.
     * The weights are the heart of the emergent-path design.
     * ------------------------------------------------------------------- */
    function chooseDestination(gnome) {
      var r = rng();
      var home = gnome.home || plaza;
      var mind = ensureMind(gnome);
      var needs = mind.needs || {};
      // Tunnel couriers occasionally set off to a partner zone (tunnelLinks
      // existing == tunnels are open for this village). They walk to this zone's
      // tunnel entrance, dig in, travel underground, and emerge at the partner.
      if (gnome.tunnelCourier && tunnelLinks.length && !gnome.missionPhase && !gnome.sampleCarried && rng() < 0.12) {
        var exit = pickTunnelExit(gnome);
        if (exit) return exit;
      }
      var butterflyRide = maybeChooseButterflyRide(gnome);
      if (butterflyRide) return butterflyRide;
      var expedition = maybeChooseExpedition(gnome);
      if (expedition) return expedition;

      if (gnome.role === 'build') {
        // Builder life = home <-> their work site, with regular plaza socializing.
        if ((needs.rest || 0) > 0.86 && r < 0.78) return tag(home, 'home');
        if ((needs.social || 0) > 0.82 && r < 0.68) return plazaPOI;
        if ((needs.purpose || 0) > 0.66 && gnome.work && r < 0.86) return tag(gnome.work, 'work');
        if (r < dailyRoutine.sleepBias * 0.58) return tag(home, 'home'); // routine-sleepBias
        var plantChance = plantInteractionMultiplier * 0.055 * (0.4 + dailyRoutine.forageBias);
        if (r < plantChance) { var bp = pickPlantPOI(); if (bp) return bp; }
        if (r < 0.18 + dailyRoutine.buildBias * 0.52 && gnome.work) return tag(gnome.work, 'work'); // routine-buildBias
        if (r < 0.72 - dailyRoutine.socialBias * 0.08) return tag(home, 'home');
        return plazaPOI;

      } else if (gnome.role === 'carry') {
        // Carrier life = shuttle work <-> well <-> plaza (the logistics loop).
        if ((needs.rest || 0) > 0.88 && r < 0.72) return tag(home, 'home');
        if ((needs.supplies || 0) > 0.70 && wells.length && r < 0.80) return tag(pick(wells), 'well');
        if ((needs.social || 0) > 0.86 && r < 0.64) return plazaPOI;
        if (r < dailyRoutine.sleepBias * 0.44) return tag(home, 'home');
        var carryPlantChance = plantInteractionMultiplier * 0.10 * (0.35 + dailyRoutine.forageBias);
        if (r < carryPlantChance) { var cp = pickPlantPOI(); if (cp) return cp; }
        if (r < 0.20 + dailyRoutine.buildBias * 0.28 && works.length) return tag(pick(works), 'work');
        if (r < 0.45 + dailyRoutine.forageBias * 0.22 && wells.length) return tag(pick(wells), 'well');
        return plazaPOI;
      }
      // idle: loiter home <-> plaza <-> a neighbor. Plaza-heavy.
      if ((needs.rest || 0) > 0.84 && r < 0.74) return tag(home, 'home');
      if ((needs.curiosity || 0) > 0.72) { var curiousPlant = pickPlantPOI(); if (curiousPlant && r < 0.70) return curiousPlant; }
      if ((needs.social || 0) > 0.72 && r < 0.78) return plazaPOI;
      if (r < dailyRoutine.sleepBias * 0.62) return tag(home, 'home');
      var idlePlantChance = plantInteractionMultiplier * 0.16 * (0.35 + dailyRoutine.forageBias);
      if (r < idlePlantChance) { var ip = pickPlantPOI(); if (ip) return ip; }
      if (r < 0.30) return tag(home, 'home');
      if (r < 0.34 + cooperationMultiplier * 0.04 + dailyRoutine.socialBias * 0.22) { var nb = neighborHome(home); if (nb) return tag(nb, 'home'); }
      return plazaPOI;
    }

    function pickGoal(gnome) {
      var dest = chooseDestination(gnome) || plazaPOI;

      // Decide whether to relay THROUGH the plaza. Only when the destination
      // isn't already the plaza and the gnome isn't basically standing on it.
      gnome.relay = null;
      var p = PLAZA_RELAY[gnome.role] != null ? PLAZA_RELAY[gnome.role] : 0.4;
      if (dest.kind !== 'plaza' && dest.kind !== 'expeditionPlant' && dest.kind !== 'butterfly' && rng() < p) {
        var farFromPlaza = dist2(gnome.x, gnome.z, plaza.x, plaza.z) > (ARRIVE * 3) * (ARRIVE * 3);
        if (farFromPlaza) gnome.relay = plazaPOI;
      }

      gnome.goal = dest.allowOutside ? clampExploration(dest) : clampInside(dest);
      gnome.route = planRoute(gnome, gnome.goal, gnome.relay);
      gnome.routeIndex = 0;
      gnome.relay = null;
      gnome.stuckScore = 0;
      gnome.legStartX = gnome.x;
      gnome.legStartZ = gnome.z;
      gnome.legPhase += rand(0.4, 2.2);   // fresh wobble each leg
      ensureMind(gnome).intent = intentFor(gnome, gnome.goal);
      gnome.action = dest.kind === 'expeditionPlant' || dest.kind === 'butterfly' ? 'walk' : ((gnome.role === 'carry') ? 'carry' : 'walk');
    }

    /* dwell action + duration when a gnome reaches a POI of a given kind.
     * Every action returned is one poseGnome already handles
     * (walk|idle|build|cheer|carry). Wells map to 'carry' (hauling water). */
    function arriveAt(gnome, kind) {
      var d, act;
      if (kind === 'work' || kind === 'build') { d = DWELL.work; act = 'build'; }
      else if (kind === 'well') { d = DWELL.well; act = 'carry'; }
      else if (kind === 'expeditionPlant') {
        if (gnome.goal && gnome.goal.canClimb) {
          beginGrappleSequence(gnome, gnome.goal);
          settleMindAt(gnome, kind);
          return;
        } else {
          beginCollectionSequence(gnome, gnome.goal, false);
          settleMindAt(gnome, kind);
          return;
        }
      }
      else if (kind === 'butterfly') {
        if (beginButterflyRideSequence(gnome, gnome.goal)) {
          settleMindAt(gnome, kind);
          return;
        }
      }
      else if (kind === 'tunnelExit') {
        if (beginTunnelSequence(gnome, gnome.goal && gnome.goal.tunnelLink)) {
          settleMindAt(gnome, kind);
          return;
        }
        // no link (shouldn't happen) — fall through to a normal idle dwell
        d = DWELL.idle; act = 'idle';
      }
      else if (kind === 'sampleDepot') {
        d = [2.0, 4.0];
        act = rng() < 0.72 ? 'catalogSample' : 'cheer';
        gnome.sampleCarried = false;
        gnome.missionPhase = 'unpack';
        gnome.deliveredSamples = (gnome.deliveredSamples || 0) + Math.max(1, gnome.sampleYield || 1);
        gnome.nextMissionAt = (gnome.missionClock || 0) + rand(60, 180);
      }
      else if (kind === 'plant') {
        d = DWELL.plant;
        act = rng() < 0.26 && gnome.goal && gnome.goal.canClimb ? 'climb' : (rng() < 0.64 ? 'forage' : 'inspect');
      }
      else if (kind === 'plaza') {
        d = DWELL.plaza;
        var social = rng();
        if (gnome.role === 'idle' && social < (0.10 + dailyRoutine.socialBias * 0.16) * cooperationMultiplier) act = 'cheer';
        else if (social < 0.18 + cooperationMultiplier * 0.13 + dailyRoutine.socialBias * 0.28) act = 'chat';
        else act = 'idle';
      } else {
        d = DWELL.idle;
        act = rng() < 0.16 * cooperationMultiplier * (0.5 + dailyRoutine.socialBias) ? 'chat' : 'idle';
        if (dailyRoutine.sleepBias > 0.7) {
          d = [d[0] * 1.8, d[1] * 2.4];
          gnome.restingInside = rng() < dailyRoutine.sleepBias * 0.78;
        } else {
          gnome.restingInside = false;
        }
      }   // home / neighbor
      gnome.dwell = rand(d[0], d[1]);
      gnome.action = act;
      settleMindAt(gnome, kind);
    }

    /* ---------------------------------------------------------------------
     * stepGnome — advance one frame, depositing wear under the feet.
     * ------------------------------------------------------------------- */
    function stepGnome(gnome, dt, deposit) {
      if (!gnome || !dt) return;
      gnome.missionClock = (gnome.missionClock || 0) + dt;
      updateMind(gnome, dt);
      if (gnome.goal === undefined || gnome.goal === null) pickGoal(gnome);
      var socialAwareness = neighborAwareness(gnome);

      // ---- dwelling: stand still, hold the stationary pose, then re-route ----
      if (gnome.dwell > 0) {
        if (gnome.group) gnome.group.visible = !gnome.restingInside;
        gnome.dwell -= dt;
        if (gnome.missionPhase === 'grappleShoot') {
          var shootDuration = Math.max(0.1, gnome.grappleShootDuration || 0.56);
          gnome.grappleShootProgress = clampN(1 - gnome.dwell / shootDuration, 0, 1);
          gnome.grappleProgress = gnome.grappleShootProgress;
          gnome.grappleTension = clampN(0.08 + gnome.grappleShootProgress * 0.34, 0, 0.48);
        }
        if (gnome.tunnelPhase === 'tunnelDigIn') {
          var digDuration = Math.max(0.1, gnome.tunnelDigDuration || 1.6);
          gnome.tunnelProgress = clampN(1 - gnome.dwell / digDuration, 0, 1);
        } else if (gnome.tunnelPhase === 'tunnelEmerge') {
          var emergeDuration = Math.max(0.1, gnome.tunnelEmergeDuration || 1.6);
          gnome.tunnelEmergeProgress = clampN(1 - gnome.dwell / emergeDuration, 0, 1);
        }
        if (gnome.missionPhase === 'canopyInspect' || gnome.missionPhase === 'fieldInspect' || gnome.missionPhase === 'extractTap' || gnome.missionPhase === 'sampleBundle') {
          var stageDuration = Math.max(0.1, gnome.resourceCollectionStageDuration || 1);
          gnome.resourceCollectionStageProgress = clampN(1 - gnome.dwell / stageDuration, 0, 1);
          var baseProgress = gnome.missionPhase === 'sampleBundle' ? 0.74 : (gnome.missionPhase === 'extractTap' ? 0.34 : 0);
          var spanProgress = gnome.missionPhase === 'sampleBundle' ? 0.26 : (gnome.missionPhase === 'extractTap' ? 0.40 : 0.34);
          gnome.resourceCollectionProgress = clampN(baseProgress + gnome.resourceCollectionStageProgress * spanProgress, 0, 1);
          var wp = gnome.resourceCollectionWorkPoint;
          if (wp && gnome.resourceCollectionElevated) {
            // Hang on the rope beside the canopy and work — a small natural
            // sway and bob, NOT a full orbit (which read as spinning in place).
            var swayT = (gnome.missionClock || 0) * 1.5 + (gnome.grappleLineJitter || 0) * 3.0;
            gnome.x = wp.x + Math.sin(swayT) * 0.55;
            gnome.z = wp.z + Math.cos(swayT * 0.8) * 0.4;
            gnome.ziplineHeight = Math.max(10, wp.y - 14 + Math.sin(swayT * 1.3) * 0.6);
            // Face outward toward the village, held steady so it never pirouettes.
            if (gnome.canopyFacing == null) {
              gnome.canopyFacing = Math.atan2(plaza.x - wp.x, plaza.z - wp.z);
            }
            gnome.heading = turnToward(gnome.heading != null ? gnome.heading : gnome.canopyFacing, gnome.canopyFacing, 2.4, dt);
          } else if (wp) {
            var shuffle = Math.sin((gnome.missionClock || 0) * 2.2 + (gnome.legPhase || 0));
            gnome.x += shuffle * 0.025;
            gnome.z += Math.cos((gnome.missionClock || 0) * 2.0 + (gnome.legPhase || 0)) * 0.018;
            gnome.heading = turnToward(gnome.heading || 0, Math.atan2(wp.x - gnome.x, wp.z - gnome.z), 3.6, dt);
          }
        }
        // ---- personal space while standing around ----------------------------
        // A relaxed gnome eases out of any neighbor's personal bubble and turns to
        // face the gathering, so a cluster settles into a natural little group
        // instead of an overlapping, all-facing-the-same-way lineup. Mission /
        // tunnel / carrying gnomes manage their own footing and are left alone.
        if (!gnome.missionPhase && !gnome.tunnelPhase && !gnome.sampleCarried && !gnome.restingInside) {
          var crowd = neighborAwareness(gnome);
          if (crowd.nearest && crowd.nearestDistance < PERSONAL_SPACE * 0.82) {
            var ease = clampN((PERSONAL_SPACE * 0.82 - crowd.nearestDistance) / PERSONAL_SPACE, 0, 1);
            var spread = movementClamp(gnome, {
              x: gnome.x + crowd.x * ease * SPEED * 0.16 * dt,
              z: gnome.z + crowd.z * ease * SPEED * 0.16 * dt
            }, null);
            gnome.x = spread.x;
            gnome.z = spread.z;
            if (gnome.action === 'chat' || gnome.action === 'idle' || gnome.action === 'cheer') {
              var faceX = crowd.nearest.x - gnome.x;
              var faceZ = crowd.nearest.z - gnome.z;
              if ((faceX * faceX + faceZ * faceZ) > 1) {
                gnome.heading = turnToward(gnome.heading || 0, Math.atan2(faceX, faceZ), 2.0, dt);
              }
            }
          }
        }
        if (gnome.dwell <= 0) {
          gnome.dwell = 0;
          gnome.restingInside = false;
          if (gnome.group) gnome.group.visible = true;
          if (gnome.missionPhase === 'climbing') {
            gnome.missionPhase = 'sampling';
            gnome.dwell = rand(2.6, 4.8);
            gnome.action = 'sample';
            return;
          }
          if (gnome.missionPhase === 'grappleAim') {
            gnome.missionPhase = 'grappleShoot';
            gnome.grappleShootDuration = rand(0.42, 0.74);
            gnome.dwell = gnome.grappleShootDuration;
            gnome.grappleShootProgress = 0;
            gnome.grappleProgress = 0;
            gnome.grappleTension = 0.08;
            gnome.action = 'grappleShoot';
            return;
          }
          if (gnome.missionPhase === 'grappleShoot') {
            gnome.missionPhase = 'ziplineUp';
            gnome.grappleProgress = 0;
            gnome.grappleShootProgress = 1;
            gnome.grappleTension = 0.42;
            gnome.dwell = 0;
            gnome.action = 'zipline';
            return;
          }
          if (gnome.missionPhase === 'butterflyMount') {
            gnome.missionPhase = 'butterflyLaunch';
            gnome.butterflyRideProgress = 0;
            gnome.dwell = 0;
            gnome.action = 'butterflyRide';
            return;
          }
          if (gnome.tunnelPhase === 'tunnelDigIn') {
            // dug in — go underground (invisible) and march the transit progress.
            gnome.tunnelPhase = 'tunnelUnderground';
            gnome.missionPhase = 'tunnelUnderground';
            gnome.tunnelProgress = 0;
            gnome.dwell = 0;
            if (gnome.group) gnome.group.visible = false;
            return;
          }
          if (gnome.tunnelPhase === 'tunnelEmerge') {
            // fully surfaced at the partner entrance — flag for main.js handoff.
            gnome.tunnelPhase = 'tunnelArrived';
            gnome.missionPhase = 'tunnelArrived';
            gnome.tunnelEmergeProgress = 1;
            gnome.dwell = 0;
            if (gnome.group) gnome.group.visible = true;
            gnome.action = 'idle';
            return;
          }
          if (gnome.missionPhase === 'sampling') {
            if (gnome.grappleAnchor) {
              gnome.missionPhase = 'rappelDown';
              gnome.grappleProgress = 0;
              gnome.grappleTension = 1;
              gnome.dwell = 0;
              gnome.action = 'rappel';
            } else {
              beginReturnWithSample(gnome);
            }
            return;
          }
          if (advanceCollectionSequence(gnome)) {
            return;
          }
          if (gnome.missionPhase === 'unpack') {
            gnome.missionPhase = null;
            gnome.missionTarget = null;
            gnome.grappleAnchor = null;
            gnome.grappleOrigin = null;
            gnome.grappleProgress = 0;
            gnome.grappleShootProgress = 0;
            gnome.grappleTension = 0;
            gnome.ziplineHeight = 0;
            gnome.resourceCollectionWorkPoint = null;
            gnome.resourceCollectionStageProgress = 0;
          }
          if (gnome.missionPhase === 'butterflyRelease') {
            clearButterflyRide(gnome);
          }
          pickGoal(gnome);
        }
        // a stationary gnome lightly packs the spot it stands on (foot scuff);
        // butterfly mounting/release stays airy so it doesn't carve odd ground paths.
        if (typeof deposit === 'function' && gnome.missionPhase !== 'butterflyMount' && gnome.missionPhase !== 'butterflyRelease') {
          deposit(gnome.x, gnome.z, DEPOSIT_BASE * 0.25 * dt);
        }
        return;
      }
      if (gnome.group) gnome.group.visible = true;
      if (stepGrappleSequence(gnome, dt)) {
        if (typeof deposit === 'function' && gnome.missionPhase === 'rappelDown') {
          deposit(gnome.x, gnome.z, DEPOSIT_BASE * 0.14 * dt);
        }
        return;
      }
      if (stepButterflyRideSequence(gnome, dt)) {
        return;
      }
      if (stepTunnelSequence(gnome, dt)) {
        return;
      }
      // A gnome that has surfaced at a partner zone waits (still, no walk) until
      // main.js performs the cross-village hand-off and re-assigns it a goal.
      if (gnome.tunnelPhase === 'tunnelArrived') {
        gnome.action = 'idle';
        return;
      }
      if (maybeSocialPause(gnome, socialAwareness, dt)) {
        if (typeof deposit === 'function') deposit(gnome.x, gnome.z, DEPOSIT_BASE * 0.2 * dt);
        return;
      }

      var route = (gnome.route && gnome.route.length) ? gnome.route : null;
      if (!route && gnome.goal) {
        gnome.route = planRoute(gnome, gnome.goal, gnome.relay);
        gnome.routeIndex = 0;
        gnome.relay = null;
        route = gnome.route;
      }
      if (route && gnome.routeIndex >= route.length) gnome.routeIndex = Math.max(0, route.length - 1);
      var target = route ? route[gnome.routeIndex || 0] : (gnome.relay || gnome.goal);
      if (!target) { pickGoal(gnome); return; }
      var finalTarget = !route || (gnome.routeIndex || 0) >= route.length - 1;

      var dx = target.x - gnome.x, dz = target.z - gnome.z;
      var d = Math.sqrt(dx * dx + dz * dz);

      // ---- arrival ----
      var arriveR = finalTarget ? ARRIVE : ARRIVE * 1.15;  // loose pass-through at interior waypoints
      if (d <= arriveR) {
        gnome.x = target.x; gnome.z = target.z;
        if (typeof deposit === 'function') deposit(gnome.x, gnome.z, DEPOSIT_BASE * dt);
        if (!finalTarget) {
          gnome.routeIndex = (gnome.routeIndex || 0) + 1;
          gnome.legStartX = gnome.x; gnome.legStartZ = gnome.z;
          gnome.legPhase += rand(0.3, 1.5);
        } else {
          arriveAt(gnome, gnome.goal.kind);
        }
        return;
      }

      // ---- heading toward target, with a gentle perpendicular meander -------
      var ux = dx / d, uz = dz / d;          // forward unit
      var px = -uz, pz = ux;                  // left-perpendicular unit

      // meander fades to zero near the endpoints so leg ends converge cleanly
      // (clean convergence is what lets a sharp plaza/doorstep hotspot form).
      var legLen = Math.max(1, Math.sqrt(
        dist2(gnome.legStartX, gnome.legStartZ, target.x, target.z)));
      var travelled = Math.sqrt(dist2(gnome.legStartX, gnome.legStartZ, gnome.x, gnome.z));
      var u = clampN(travelled / legLen, 0, 1);
      var taper = Math.sin(u * Math.PI);      // 0 at both ends, 1 mid-leg
      var wob = Math.sin(u * Math.PI * 2 * MEANDER_FREQ + gnome.legPhase) * MEANDER_AMPL * taper;

      var missionRunMultiplier = (gnome.missionPhase === 'return' && gnome.sampleCarried) ? 1.28 : 1;
      var sp = SPEED * (gnome.speed || 1) * missionRunMultiplier;
      var stepLen = Math.min(d, sp * dt);     // don't overshoot
      var pressureNow = boundaryPressureAt(gnome.x, gnome.z);
      var boundarySlowdown = 1 - pressureNow.strength * 0.16;
      stepLen *= clampN(boundarySlowdown, 0.76, 1);

      var nx = gnome.x + ux * stepLen + px * wob * dt * 1.4;
      var nz = gnome.z + uz * stepLen + pz * wob * dt * 1.4;
      if (!target.allowOutside && pressureNow.strength > 0.001) {
        nx += pressureNow.x * pressureNow.strength * stepLen * 0.38;
        nz += pressureNow.z * pressureNow.strength * stepLen * 0.38;
      }
      if (!target.allowOutside && socialAwareness.strength > 0.001) {
        nx += socialAwareness.x * socialAwareness.strength * stepLen * 0.42;
        nz += socialAwareness.z * socialAwareness.strength * stepLen * 0.42;
      }

      // keep inside the user-drawn village area, not just its rectangle bounds
      var rawX = nx;
      var rawZ = nz;
      var beforeX = gnome.x;
      var beforeZ = gnome.z;
      var inside = movementClamp(gnome, { x: nx, z: nz, kind: target.kind }, target);
      nx = inside.x;
      nz = inside.z;

      gnome.x = nx; gnome.z = nz;
      var moved = Math.sqrt(dist2(beforeX, beforeZ, nx, nz));
      var clampShift = Math.sqrt(dist2(rawX, rawZ, nx, nz));
      var desiredHeading = Math.atan2(ux, uz);     // +Z-forward yaw for the rig
      gnome.heading = turnToward(gnome.heading || desiredHeading, desiredHeading, 7.5, dt);

      var routeIsBlocked = !target.allowOutside && !segmentInside({ x: gnome.x, z: gnome.z }, target);
      if (moved < Math.max(0.04, stepLen * 0.20) || clampShift > Math.max(0.8, stepLen * 0.55) || routeIsBlocked) {
        gnome.stuckScore = (gnome.stuckScore || 0) + dt * (1 + pressureNow.strength * 0.8);
      } else {
        gnome.stuckScore = Math.max(0, (gnome.stuckScore || 0) - dt * 2.1);
      }
      ensureMind(gnome).boundaryAwareness = pressureNow.strength;
      if (gnome.stuckScore > STUCK_REPLAN_AT && gnome.goal) {
        gnome.route = planRoute(gnome, gnome.goal, null);
        gnome.routeIndex = 0;
        gnome.legStartX = gnome.x;
        gnome.legStartZ = gnome.z;
        gnome.legPhase += rand(0.7, 2.1);
        gnome.stuckScore = 0.35;
        gnome.action = 'inspect';
      }

      if (gnome.action !== 'inspect' || (gnome.stuckScore || 0) < 0.05) {
        gnome.action = gnome.sampleCarried ? 'carry' : ((gnome.role === 'carry') ? 'carry' : 'walk');
      }

      // ---- WEAR: deposit under the feet. Heavy haulers pack harder. ----
      if (typeof deposit === 'function') {
        var roleW = gnome.role === 'carry' ? 1.25 : (gnome.role === 'build' ? 1.0 : 0.85);
        deposit(gnome.x, gnome.z, DEPOSIT_BASE * roleW * dt);
      }
    }

    /* POIs exposed so the renderer can place markers / debug-draw them */
    var pois = {
      plaza: plazaPOI,
      homes: homes.map(function (h) { return tag(h, 'home'); }),
      works: works.map(function (w) { return tag(w, 'work'); }),
      wells: wells.map(function (w) { return tag(w, 'well'); })
      , expeditionPlants: expeditionPlants.map(function (p) { return tag(p, 'expeditionPlant'); })
      , butterflies: butterflies.map(function (p) { return tag(p, 'butterfly'); })
    };

    return {
      assign: assign,
      stepGnome: stepGnome,
      setSimulation: updateSimulation,
      setDailyRoutine: updateDailyRoutine,
      setTunnelLinks: updateTunnelLinks,
      removeResident: removeResident,
      planRouteForTesting: function (gnome, destination) {
        return planRoute(gnome || { x: plaza.x, z: plaza.z }, destination || plazaPOI, null);
      },
      segmentInsideForTesting: segmentInside,
      pois: pois
    };
  };

  /* ============================ MATH NOTE ================================== *
   * DECAY_RATE = 0.0163/s -> keep(dt)=exp(-0.0163*dt). A well-worn cell (wear=1)
   *   decays below the alpha floor (wear < ALPHA_KNEE=0.16) in ~112s — inside the
   *   90-120s abandonment window. (-ln(0.16)/0.0163 ~= 112.)
   *
   * DEPOSIT_GAIN = 0.34 with strength = roleW*dt per frame: per pass over a cell
   *   at ~22 u/s the cell collects ~0.3-0.5s of gaussian-weighted exposure
   *   (SIGMA=0.95, 2-cell reach). With decay running, route-center wear lands
   *   ~PAVE_AT (1.0) after ~18-26 passes and saturates near cobble by ~32 — a
   *   route walked ~15-30x over ~60s visibly paves, then saturates.
   *
   * Plaza relay (build 0.34 / carry 0.40 / idle 0.55) makes the center the
   *   single highest-traffic cell, so the hub plaza wears in ~3x the next-busiest
   *   route. Meander taper = sin(u*PI) keeps endpoints sharp (crisp doorsteps).
   * ========================================================================*/
})();
