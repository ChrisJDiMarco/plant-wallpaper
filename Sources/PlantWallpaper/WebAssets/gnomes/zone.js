/* ============================================================================
 * WallpaperGarden — Zone Placement + Scene Helpers (SimCity-style)
 * three.js r128, global THREE. No modules, no loaders, no CapsuleGeometry.
 * World convention: Y up, ground = XZ at y=0, characters face +Z.
 *
 * Public API:
 *   populateZone(polygon, opts)   -> data description (plaza, sites, paths, props)
 *   buildZone(description, opts)   -> THREE.Group of houses/roads/plaza/props
 *   makeZoneOutline(polygon, opts) -> glowing drawn-boundary ribbon (no ground)
 *   makeShadowCatcher(opts)        -> invisible ShadowMaterial plane @ y=0
 *   spawnZone(polygon, opts)       -> { group, description } (does it all)
 *
 *   `polygon` = array of {x,z} ground points (the user-drawn region).
 * Scale: houses authored so cottage walls ≈ s*0.8 ≈ 9-22 units; pass
 *   opts.build.houseScale to match the ~26u gnomes / ~24u build-sites.
 * Uses host scene's mat(hex,opts) if present, else an inline fallback.
 * ==========================================================================*/

var ZONE_mat = (typeof texturedMat === 'function')
  ? function (colorHex, opts) {
      opts = opts || {};
      return texturedMat(colorHex, opts.kind || 'plaster', opts);
    }
  : (typeof mat === 'function')
    ? mat
    : function (colorHex, opts) {
        opts = opts || {};
        return new THREE.MeshStandardMaterial({
          color: new THREE.Color(colorHex),
          roughness: opts.roughness != null ? opts.roughness : 0.8,
          metalness: opts.metalness != null ? opts.metalness : 0.0,
          emissive: new THREE.Color(opts.emissive != null ? opts.emissive : 0x000000),
          emissiveIntensity: opts.emissiveIntensity != null ? opts.emissiveIntensity : 0,
          transparent: !!opts.transparent,
          opacity: opts.opacity != null ? opts.opacity : 1
        });
      };

/* ===== 0. SEEDED RNG (mulberry32) ===== */
function mulberry32(seed) {
  var a = seed >>> 0;
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    var t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/* ===== 1. GEOMETRY HELPERS (on {x,z} points) ===== */
function pointInPolygon(px, pz, poly) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    var xi = poly[i].x, zi = poly[i].z, xj = poly[j].x, zj = poly[j].z;
    if (((zi > pz) !== (zj > pz))) {
      var xCross = ((xj - xi) * (pz - zi)) / ((zj - zi) || 1e-9) + xi;
      if (px < xCross) inside = !inside;
    }
  }
  return inside;
}
function polygonCentroid(poly) {
  var area = 0, cx = 0, cz = 0;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    var cross = poly[j].x * poly[i].z - poly[i].x * poly[j].z;
    area += cross;
    cx += (poly[j].x + poly[i].x) * cross;
    cz += (poly[j].z + poly[i].z) * cross;
  }
  area *= 0.5;
  if (Math.abs(area) < 1e-6) {
    var sx = 0, sz = 0;
    for (var k = 0; k < poly.length; k++) { sx += poly[k].x; sz += poly[k].z; }
    return { x: sx / poly.length, z: sz / poly.length };
  }
  return { x: cx / (6 * area), z: cz / (6 * area) };
}
function polygonBounds(poly) {
  var minX = Infinity, maxX = -Infinity, minZ = Infinity, maxZ = -Infinity;
  for (var i = 0; i < poly.length; i++) {
    var p = poly[i];
    if (p.x < minX) minX = p.x; if (p.x > maxX) maxX = p.x;
    if (p.z < minZ) minZ = p.z; if (p.z > maxZ) maxZ = p.z;
  }
  return { minX: minX, maxX: maxX, minZ: minZ, maxZ: maxZ, w: maxX - minX, h: maxZ - minZ };
}
function snapInside(p, poly, bounds) {
  if (pointInPolygon(p.x, p.z, poly)) return { x: p.x, z: p.z };
  var span = Math.max(bounds.w, bounds.h) || 1;
  for (var r = span * 0.04; r < span; r += span * 0.04) {
    for (var a = 0; a < Math.PI * 2; a += Math.PI / 12) {
      var x = p.x + Math.cos(a) * r, z = p.z + Math.sin(a) * r;
      if (pointInPolygon(x, z, poly)) return { x: x, z: z };
    }
  }
  return { x: p.x, z: p.z };
}
function polygonArea(poly) {
  var area = 0;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    area += poly[j].x * poly[i].z - poly[i].x * poly[j].z;
  }
  return Math.abs(area) * 0.5;
}
function smoothPath(points, subdivisions) {
  if (points.length < 3) return points.slice();
  subdivisions = subdivisions || 8;
  var out = [], pts = points;
  for (var i = 0; i < pts.length - 1; i++) {
    var p0 = pts[i - 1] || pts[i], p1 = pts[i], p2 = pts[i + 1], p3 = pts[i + 2] || p2;
    for (var s = 0; s < subdivisions; s++) {
      var t = s / subdivisions, t2 = t * t, t3 = t2 * t;
      out.push({
        x: 0.5 * ((2 * p1.x) + (-p0.x + p2.x) * t + (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 + (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3),
        z: 0.5 * ((2 * p1.z) + (-p0.z + p2.z) * t + (2 * p0.z - 5 * p1.z + 4 * p2.z - p3.z) * t2 + (-p0.z + 3 * p1.z - 3 * p2.z + p3.z) * t3)
      });
    }
  }
  out.push(pts[pts.length - 1]);
  return out;
}
function marchInside(from, target, poly) {
  for (var i = 0; i <= 24; i++) {
    var t = i / 24;
    var x = from.x + (target.x - from.x) * t, z = from.z + (target.z - from.z) * t;
    if (pointInPolygon(x, z, poly)) return { x: x, z: z };
  }
  return { x: target.x, z: target.z };
}

/* ===== 2. populateZone — the planner (DATA ONLY) =====
 * Returns { plaza, sites:[{x,z,rotation,type}], paths:[[{x,z}...]],
 *           props:[{x,z,type,rotation}], buildSites:[idx...], bounds, centroid, seed, minSpacing }
 * A subset of sites are flagged as live BUILD SITES (type 'build') so the
 * caller can spawn makeBuildSite() there and slowly advance setProgress. */
function populateZone(polygon, opts) {
  opts = opts || {};
  if (!polygon || polygon.length < 3) {
    return { plaza: { x: 0, z: 0 }, sites: [], paths: [], props: [], buildSites: [], bounds: null };
  }
  var seed = opts.seed != null ? opts.seed : 1337;
  var rng = mulberry32(seed);
  var bounds = polygonBounds(polygon);
  var area = polygonArea(polygon);
  var diag = Math.sqrt(bounds.w * bounds.w + bounds.h * bounds.h) || 1;
  var detailMultiplier = opts.detailMultiplier != null
    ? Math.max(0.5, Math.min(2.0, opts.detailMultiplier))
    : 1.0;

  var centroid = polygonCentroid(polygon);
  var plaza = snapInside(centroid, polygon, bounds);

  var minSpacing = opts.minSpacing != null ? opts.minSpacing : Math.max(34, diag * 0.10);
  var plazaClearance = opts.plazaClearance != null ? opts.plazaClearance : minSpacing * 1.25;
  var edgeMargin = opts.edgeMargin != null ? opts.edgeMargin : minSpacing * 0.45;
  var targetSites = opts.siteCount != null
    ? opts.siteCount
    : Math.max(4, Math.min(52, Math.round((area / (minSpacing * minSpacing * 3.2)) * detailMultiplier)));
  var houseTypes = opts.houseTypes || ['cottage', 'cottage', 'cottage', 'hall', 'tower'];

  var sites = [], accepted = [plaza];
  var maxTries = targetSites * 320, tries = 0;
  while (sites.length < targetSites && tries < maxTries) {
    tries++;
    var x = bounds.minX + rng() * bounds.w;
    var z = bounds.minZ + rng() * bounds.h;
    if (!pointInPolygon(x, z, polygon)) continue;
    if (edgeMargin > 0) {
      if (!pointInPolygon(x + edgeMargin, z, polygon)) continue;
      if (!pointInPolygon(x - edgeMargin, z, polygon)) continue;
      if (!pointInPolygon(x, z + edgeMargin, polygon)) continue;
      if (!pointInPolygon(x, z - edgeMargin, polygon)) continue;
    }
    var pdx = x - plaza.x, pdz = z - plaza.z;
    if (pdx * pdx + pdz * pdz < plazaClearance * plazaClearance) continue;
    var ok = true;
    for (var ai = 0; ai < accepted.length; ai++) {
      var dx = accepted[ai].x - x, dz = accepted[ai].z - z;
      if (dx * dx + dz * dz < minSpacing * minSpacing) { ok = false; break; }
    }
    if (!ok) continue;
    var rotation = Math.atan2(plaza.x - x, plaza.z - z);  // faces +Z toward plaza
    var type = houseTypes[(rng() * houseTypes.length) | 0];
    var site = { x: x, z: z, rotation: rotation, type: type };
    sites.push(site); accepted.push(site);
  }

  // flag ~1/3 of sites as live build sites (rounded up, at least 1 if any sites)
  var buildSites = [];
  var nBuild = Math.max(sites.length ? 1 : 0, Math.round(sites.length / (3.4 - Math.min(1.3, detailMultiplier * 0.55))));
  for (var bi = 0; bi < sites.length && buildSites.length < nBuild; bi += 3) {
    sites[bi].type = 'build';
    buildSites.push(bi);
  }

  // ----- roads -----
  var paths = [];
  var horizontalLong = bounds.w >= bounds.h;
  var spineA = marchInside(horizontalLong ? { x: bounds.minX, z: plaza.z } : { x: plaza.x, z: bounds.minZ }, plaza, polygon);
  var spineB = marchInside(horizontalLong ? { x: bounds.maxX, z: plaza.z } : { x: plaza.x, z: bounds.maxZ }, plaza, polygon);
  paths.push(smoothPath([spineA, plaza, spineB], 10));
  for (var si = 0; si < sites.length; si++) {
    var s = sites[si];
    var mid = {
      x: (s.x + plaza.x) * 0.5 + (rng() - 0.5) * minSpacing * 0.6,
      z: (s.z + plaza.z) * 0.5 + (rng() - 0.5) * minSpacing * 0.6
    };
    var midInside = pointInPolygon(mid.x, mid.z, polygon) ? mid : { x: (s.x + plaza.x) * 0.5, z: (s.z + plaza.z) * 0.5 };
    paths.push(smoothPath([s, midInside, plaza], 8));
  }

  // ----- props along roads -----
  var props = [];
  var propStride = opts.propStride != null ? opts.propStride : minSpacing * (1.05 - Math.min(0.45, detailMultiplier * 0.22));
  var propTypes = ['lantern', 'barrel', 'stall', 'signpost', 'lantern'];
  var propTick = 0;
  for (var pi = 0; pi < paths.length; pi++) {
    var path = paths[pi], acc = 0;
    for (var i = 1; i < path.length; i++) {
      var a = path[i - 1], b = path[i];
      var dxx = b.x - a.x, dzz = b.z - a.z;
      var segLen = Math.sqrt(dxx * dxx + dzz * dzz) || 1e-6;
      acc += segLen;
      if (acc < propStride) continue;
      acc = 0;
      var side = (propTick % 2 === 0) ? 1 : -1;
      var offset = (minSpacing * 0.42) * side;
      var px = b.x + (-dzz / segLen) * offset, pz = b.z + (dxx / segLen) * offset;
      if (!pointInPolygon(px, pz, polygon)) continue;
      var ddx = px - plaza.x, ddz = pz - plaza.z;
      if (ddx * ddx + ddz * ddz < (plazaClearance * 0.7) * (plazaClearance * 0.7)) continue;
      props.push({ x: px, z: pz, type: propTypes[propTick % propTypes.length], rotation: Math.atan2(plaza.x - px, plaza.z - pz) });
      propTick++;
    }
  }
  props.push({ x: plaza.x + plazaClearance * 0.6, z: plaza.z, type: 'signpost', rotation: 0 });

  return { plaza: plaza, sites: sites, paths: paths, props: props, buildSites: buildSites,
           bounds: bounds, centroid: centroid, seed: seed, minSpacing: minSpacing };
}

/* ===== 3. buildZone — turn a description into THREE meshes ===== */
function buildZone(description, opts) {
  opts = opts || {};
  var group = new THREE.Group(); group.name = 'zone';

  var M = {
    plazaStone: ZONE_mat(0x9b948a, { kind: 'cobble', roughness: 0.92 }),
    plazaRim:   ZONE_mat(0xc7bda8, { kind: 'stone',  roughness: 0.88 }),
    road:       ZONE_mat(0xb89a64, { kind: 'cobble', roughness: 0.95, repeat: [6, 6] }),
    wall:       ZONE_mat(0xcdb892, { kind: 'plaster' }),
    wallTower:  ZONE_mat(0xb9a079, { kind: 'stone' }),
    roof:       ZONE_mat(0x7d4a30, { kind: 'thatch' }),
    roofHall:   ZONE_mat(0x6b3f2a, { kind: 'thatch' }),
    door:       ZONE_mat(0x4c2e22, { kind: 'plank' }),
    windowLit:  ZONE_mat(0xffd778, { kind: 'plaster', emissive: 0xffbd55, emissiveIntensity: 0.9, roughness: 0.4 }),
    wood:       ZONE_mat(0x74482f, { kind: 'wood' }),
    barrel:     ZONE_mat(0x6b4a2c, { kind: 'plank' }),
    hoop:       ZONE_mat(0x3a2a1c, { kind: 'metal', roughness: 0.7, metalness: 0.2 }),
    canvas:     ZONE_mat(0xd8c28d, { kind: 'linen' }),
    sign:       ZONE_mat(0x8a6b45, { kind: 'plank' }),
    leaf:       ZONE_mat(0x4e7f45, { kind: 'leaf', roughness: 0.82 }),
    flowerA:    ZONE_mat(0xd86a7c, { kind: 'petal', roughness: 0.8 }),
    flowerB:    ZONE_mat(0xf3d05a, { kind: 'petal', roughness: 0.8 }),
    mushroom:   ZONE_mat(0xb94332, { kind: 'plaster', roughness: 0.86 }),
    mushroomSpot: ZONE_mat(0xf4ead8, { kind: 'plaster', roughness: 0.9 }),
    warmGlass:  ZONE_mat(0xffdf8a, { kind: 'glass', emissive: 0xffbd55, emissiveIntensity: 0.55, transparent: true, opacity: 0.7, roughness: 0.38 }),
    lanternGlow: ZONE_mat(0xffd46a, { kind: 'plaster', emissive: 0xffbd55, emissiveIntensity: 1.1, transparent: true, opacity: 0.85, roughness: 0.3 })
  };

  var plazaR = description.minSpacing ? description.minSpacing * 1.1 : 22;
  if (!opts.noPlaza) group.add(makePlaza(description.plaza, plazaR, M));

  if (!opts.noRoads) {
    var roadWidth = opts.roadWidth != null ? opts.roadWidth : (description.minSpacing ? description.minSpacing * 0.32 : 7);
    for (var i = 0; i < description.paths.length; i++) {
      var ribbon = makeRibbon(description.paths[i], roadWidth, 0.06, M.road);
      if (ribbon) group.add(ribbon);
    }
  }

  var houseScale = opts.houseScale != null ? opts.houseScale : (description.minSpacing ? description.minSpacing * 0.5 : 11);
  for (var hi = 0; hi < description.sites.length; hi++) {
    // 'build' sites are placeholders — the caller spawns makeBuildSite there instead.
    if (description.sites[hi].type === 'build') continue;
    group.add(makeHouse(description.sites[hi], houseScale, M));
  }
  for (var pi = 0; pi < description.props.length; pi++) {
    var prop = makeProp(description.props[pi], M);
    if (prop) group.add(prop);
  }
  return group;
}

function makePlaza(center, radius, M) {
  var g = new THREE.Group(); g.position.set(center.x, 0, center.z);
  var disc = new THREE.Mesh(new THREE.CylinderGeometry(radius, radius, 0.6, 40), M.plazaStone);
  disc.position.y = 0.3; disc.castShadow = true; disc.receiveShadow = true; g.add(disc);
  var rim = new THREE.Mesh(new THREE.TorusGeometry(radius, 0.9, 10, 40), M.plazaRim);
  rim.rotation.x = Math.PI / 2; rim.position.y = 0.6; rim.castShadow = true; g.add(rim);
  var post = new THREE.Mesh(new THREE.CylinderGeometry(1.1, 1.4, 4.5, 14), M.plazaRim);
  post.position.y = 2.55; post.castShadow = true; g.add(post);
  var cap = new THREE.Mesh(new THREE.SphereGeometry(1.6, 16, 12), M.plazaRim);
  cap.position.y = 5.0; cap.castShadow = true; g.add(cap);
  return g;
}

function makeRibbon(points, width, y, material) {
  if (!points || points.length < 2) return null;
  var half = width * 0.5, verts = [], indices = [];
  for (var i = 0; i < points.length; i++) {
    var prev = points[i - 1] || points[i], next = points[i + 1] || points[i];
    var dx = next.x - prev.x, dz = next.z - prev.z;
    var len = Math.sqrt(dx * dx + dz * dz) || 1e-6; dx /= len; dz /= len;
    var nx = -dz, nz = dx;
    verts.push(points[i].x + nx * half, y, points[i].z + nz * half);
    verts.push(points[i].x - nx * half, y, points[i].z - nz * half);
    if (i < points.length - 1) { var a = i * 2; indices.push(a, a + 1, a + 2, a + 1, a + 3, a + 2); }
  }
  var geom = new THREE.BufferGeometry();
  geom.setAttribute('position', new THREE.Float32BufferAttribute(verts, 3));
  geom.setIndex(indices); geom.computeVertexNormals();
  var mesh = new THREE.Mesh(geom, material); mesh.receiveShadow = true;
  return mesh;
}

function makeHouse(site, scale, M) {
  var g = new THREE.Group();
  g.position.set(site.x, 0, site.z);
  g.rotation.y = site.rotation;
  var type = site.type || 'cottage', s = scale;
  if (type === 'tower') {
    var bodyT = new THREE.Mesh(new THREE.CylinderGeometry(s * 0.45, s * 0.5, s * 1.9, 16), M.wallTower);
    bodyT.position.y = s * 0.95; bodyT.castShadow = true; bodyT.receiveShadow = true; g.add(bodyT);
    var roofT = new THREE.Mesh(new THREE.ConeGeometry(s * 0.62, s * 0.9, 16), M.roof);
    roofT.position.y = s * 2.35; roofT.castShadow = true; g.add(roofT);
    addWindow(g, M, 0, s * 1.2, s * 0.46, s * 0.22);
  } else if (type === 'hall') {
    var bodyH = new THREE.Mesh(new THREE.BoxGeometry(s * 1.6, s * 0.95, s * 1.0), M.wall);
    bodyH.position.y = s * 0.48; bodyH.castShadow = true; bodyH.receiveShadow = true; g.add(bodyH);
    var roofH = new THREE.Mesh(new THREE.ConeGeometry(s * 1.15, s * 0.7, 4), M.roofHall);
    roofH.rotation.y = Math.PI / 4; roofH.position.y = s * 1.3; roofH.castShadow = true; g.add(roofH);
    addDoor(g, M, 0, s * 0.5);
    addWindow(g, M, -s * 0.5, s * 0.55, s * 0.51, s * 0.2);
    addWindow(g, M, s * 0.5, s * 0.55, s * 0.51, s * 0.2);
  } else {
    var bodyC = new THREE.Mesh(new THREE.BoxGeometry(s * 1.0, s * 0.8, s * 0.9), M.wall);
    bodyC.position.y = s * 0.4; bodyC.castShadow = true; bodyC.receiveShadow = true; g.add(bodyC);
    var roofC = new THREE.Mesh(new THREE.ConeGeometry(s * 0.82, s * 0.6, 4), M.roof);
    roofC.rotation.y = Math.PI / 4; roofC.position.y = s * 1.05; roofC.castShadow = true; g.add(roofC);
    addDoor(g, M, 0, s * 0.46);
    addWindow(g, M, s * 0.32, s * 0.45, s * 0.46, s * 0.18);
  }
  var chimney = new THREE.Mesh(new THREE.BoxGeometry(s * 0.18, s * 0.5, s * 0.18), M.roof);
  chimney.position.set(s * 0.3, s * 1.25, -s * 0.2); chimney.castShadow = true; g.add(chimney);
  addVillageHouseFidelity(g, site, s, M, type);
  return g;
}
function addDoor(parent, M, x, z) {
  var door = new THREE.Mesh(new THREE.BoxGeometry(2.2, 4.2, 0.4), M.door);
  door.position.set(x, 2.1, z); door.castShadow = true; parent.add(door);
}
function addWindow(parent, M, x, y, z, size) {
  var w = new THREE.Mesh(new THREE.PlaneGeometry(size * 8, size * 8), M.windowLit);
  w.name = 'windowLights';
  w.position.set(x, y, z + 0.02); parent.add(w);
}

function addVillageHouseFidelity(parent, site, scale, M, type) {
  var s = scale;
  var isTower = type === 'tower';
  var isHall = type === 'hall';
  var frontZ = isTower ? s * 0.52 : (isHall ? s * 0.53 : s * 0.48);
  var houseW = isTower ? s * 0.9 : (isHall ? s * 1.6 : s);
  var houseD = isTower ? s * 0.9 : (isHall ? s : s * 0.9);

  var hearthGlow = new THREE.Mesh(new THREE.SphereGeometry(s * 0.12, 12, 8), M.warmGlass);
  hearthGlow.name = 'hearthGlow';
  hearthGlow.userData.routineLight = 'home';
  hearthGlow.position.set(isTower ? 0 : -houseW * 0.18, s * 0.52, frontZ + 0.08);
  hearthGlow.scale.set(1.5, 1.0, 0.35);
  parent.add(hearthGlow);

  parent.add(makeStoneWalk(s * 0.75, s * 0.28, M, 0, frontZ + s * 0.35));
  parent.add(makeMicroFence(houseW * 1.25, houseD * 0.55, M, s));
  parent.add(makeMushroomCluster(-houseW * 0.48, frontZ + s * 0.42, s * 0.095, M));
  parent.add(makeMushroomCluster(houseW * 0.45, frontZ + s * 0.34, s * 0.075, M));

  if (!isTower) {
    parent.add(makeWindowBox(houseW * 0.26, s * 0.43, frontZ + 0.18, s * 0.34, M));
    if (isHall) parent.add(makeWindowBox(-houseW * 0.32, s * 0.52, frontZ + 0.18, s * 0.36, M));
    var clothes = makeClothesLine(houseW * 0.42, -houseD * 0.34, s * 0.72, s * 0.46, M);
    if (clothes) parent.add(clothes);
  }
}

function makeStoneWalk(length, width, M, x, z) {
  var g = new THREE.Group();
  g.position.set(x || 0, 0, z || 0);
  var stones = Math.max(3, Math.round(length / Math.max(1, width * 0.7)));
  for (var i = 0; i < stones; i++) {
    var t = stones === 1 ? 0.5 : i / (stones - 1);
    var stone = new THREE.Mesh(new THREE.CylinderGeometry(width * 0.42, width * 0.48, 0.28, 9), M.plazaRim);
    stone.position.set((t - 0.5) * length * 0.25, 0.16, t * length);
    stone.rotation.y = (i % 2 ? -0.18 : 0.2);
    stone.scale.x = 1.15 + (i % 3) * 0.08;
    stone.scale.z = 0.78 + (i % 2) * 0.16;
    stone.castShadow = true; stone.receiveShadow = true;
    g.add(stone);
  }
  return g;
}

function makeMicroFence(width, depth, M, scale) {
  var g = new THREE.Group();
  var postH = scale * 0.34;
  var z = depth * 0.5 + scale * 0.28;
  [-1, 1].forEach(function (side) {
    for (var i = 0; i < 3; i++) {
      var x = side * (width * 0.34 + i * width * 0.09);
      var post = new THREE.Mesh(new THREE.CylinderGeometry(scale * 0.025, scale * 0.035, postH, 7), M.wood);
      post.position.set(x, postH * 0.5, z + i * scale * 0.02);
      post.castShadow = true; g.add(post);
    }
  });
  [-1, 1].forEach(function (side) {
    var rail = new THREE.Mesh(new THREE.BoxGeometry(width * 0.32, scale * 0.035, scale * 0.035), M.wood);
    rail.position.set(side * width * 0.42, postH * 0.65, z + scale * 0.02);
    rail.rotation.z = side * 0.03;
    rail.castShadow = true; g.add(rail);
  });
  return g;
}

function makeWindowBox(x, y, z, width, M) {
  var g = new THREE.Group();
  g.position.set(x, y - width * 0.22, z + 0.1);
  var box = new THREE.Mesh(new THREE.BoxGeometry(width, width * 0.22, width * 0.22), M.wood);
  box.castShadow = true; g.add(box);
  for (var i = 0; i < 7; i++) {
    var leaf = new THREE.Mesh(new THREE.SphereGeometry(width * 0.055, 8, 6), M.leaf);
    leaf.position.set((i - 3) * width * 0.12, width * 0.16 + (i % 2) * width * 0.04, width * 0.06);
    leaf.scale.set(1.2, 0.65, 0.8); leaf.castShadow = true; g.add(leaf);
    if (i % 2 === 0) {
      var flower = new THREE.Mesh(new THREE.SphereGeometry(width * 0.035, 8, 6), i % 4 === 0 ? M.flowerA : M.flowerB);
      flower.position.set(leaf.position.x, leaf.position.y + width * 0.06, leaf.position.z + width * 0.04);
      flower.castShadow = true; g.add(flower);
    }
  }
  return g;
}

function makeMushroomCluster(x, z, scale, M) {
  var g = new THREE.Group();
  g.position.set(x, 0, z);
  for (var i = 0; i < 4; i++) {
    var ox = (i - 1.5) * scale * 3.1;
    var oz = (i % 2 ? 1 : -1) * scale * 1.6;
    var h = scale * (3.2 + i * 0.35);
    var stem = new THREE.Mesh(new THREE.CylinderGeometry(scale * 0.36, scale * 0.46, h, 8), M.mushroomSpot);
    stem.position.set(ox, h * 0.5, oz); stem.castShadow = true; g.add(stem);
    var cap = new THREE.Mesh(new THREE.ConeGeometry(scale * (1.2 + i * 0.12), scale * 0.86, 14), M.mushroom);
    cap.position.set(ox, h + scale * 0.28, oz); cap.castShadow = true; g.add(cap);
    var spot = new THREE.Mesh(new THREE.SphereGeometry(scale * 0.16, 7, 5), M.mushroomSpot);
    spot.position.set(ox + scale * 0.25, h + scale * 0.54, oz + scale * 0.26); spot.scale.y = 0.4; g.add(spot);
  }
  return g;
}

function makeClothesLine(x, z, width, height, M) {
  if (width < 1 || height < 1) return null;
  var g = new THREE.Group();
  var postMat = M.wood;
  [-0.5, 0.5].forEach(function (side) {
    var post = new THREE.Mesh(new THREE.CylinderGeometry(width * 0.025, width * 0.032, height, 7), postMat);
    post.position.set(x + side * width, height * 0.5, z);
    post.castShadow = true; g.add(post);
  });
  var line = new THREE.Mesh(new THREE.CylinderGeometry(width * 0.008, width * 0.008, width * 2, 5), M.sign);
  line.position.set(x, height * 0.86, z); line.rotation.z = Math.PI / 2; g.add(line);
  [0x8fb5d9, 0xe8d3a4, 0xb96a5d].forEach(function (color, i) {
    var cloth = new THREE.Mesh(new THREE.BoxGeometry(width * 0.24, height * 0.22, width * 0.018), ZONE_mat(color, { kind: 'linen', roughness: 0.96 }));
    cloth.position.set(x - width * 0.45 + i * width * 0.38, height * 0.72, z);
    cloth.rotation.z = (i - 1) * 0.06; cloth.castShadow = true; g.add(cloth);
  });
  return g;
}

function makeProp(p, M, lanternBudget) {
  var g = new THREE.Group();
  g.position.set(p.x, 0, p.z); g.rotation.y = p.rotation || 0;
  if (p.type === 'lantern') {
    var post = new THREE.Mesh(new THREE.CylinderGeometry(0.35, 0.45, 9, 8), M.wood);
    post.position.y = 4.5; post.castShadow = true; g.add(post);
    var arm = new THREE.Mesh(new THREE.CylinderGeometry(0.22, 0.22, 2.4, 6), M.wood);
    arm.rotation.z = Math.PI / 2; arm.position.set(1, 8.4, 0); arm.castShadow = true; g.add(arm);
    var glow = new THREE.Mesh(new THREE.SphereGeometry(1.0, 14, 10), M.lanternGlow);
    glow.name = 'lanternGlow';
    glow.userData.routineLight = 'lantern';
    glow.position.set(2, 8.0, 0); g.add(glow);
    // real point-light only while budget remains (caller passes a counter); else emissive-only
    if (lanternBudget && lanternBudget.n > 0) {
      var light = new THREE.PointLight(0xffbd55, 0.7, 26, 2);
      light.position.set(2, 8.0, 0); g.add(light);
      lanternBudget.n--;
    }
  } else if (p.type === 'barrel') {
    var body = new THREE.Mesh(new THREE.CylinderGeometry(1.5, 1.5, 3.4, 16), M.barrel);
    body.position.y = 1.7; body.castShadow = true; body.receiveShadow = true; g.add(body);
    [0.7, 1.7, 2.7].forEach(function (hy) {
      var hoop = new THREE.Mesh(new THREE.TorusGeometry(1.55, 0.12, 8, 18), M.hoop);
      hoop.rotation.x = Math.PI / 2; hoop.position.y = hy; hoop.castShadow = true; g.add(hoop);
    });
  } else if (p.type === 'stall') {
    var counter = new THREE.Mesh(new THREE.BoxGeometry(6, 2.4, 3), M.wood);
    counter.position.y = 1.2; counter.castShadow = true; counter.receiveShadow = true; g.add(counter);
    [-2.6, 2.6].forEach(function (sx) { [-1.2, 1.2].forEach(function (sz) {
      var post = new THREE.Mesh(new THREE.CylinderGeometry(0.2, 0.2, 6.5, 6), M.wood);
      post.position.set(sx, 3.2, sz); post.castShadow = true; g.add(post);
    }); });
    var awning = new THREE.Mesh(new THREE.ConeGeometry(5.2, 2.2, 4), M.canvas);
    awning.rotation.y = Math.PI / 4; awning.position.y = 7.4; awning.castShadow = true; g.add(awning);
  } else if (p.type === 'signpost') {
    var spost = new THREE.Mesh(new THREE.CylinderGeometry(0.3, 0.35, 7, 8), M.wood);
    spost.position.y = 3.5; spost.castShadow = true; g.add(spost);
    var board = new THREE.Mesh(new THREE.BoxGeometry(3.6, 1.4, 0.3), M.sign);
    board.position.set(0.6, 5.6, 0); board.castShadow = true; g.add(board);
  } else { return null; }
  return g;
}

/* ===== 4. makeZoneOutline — glowing drawn-boundary ribbon (no ground) ===== */
function makeZoneOutline(polygon, opts) {
  opts = opts || {};
  var g = new THREE.Group(); g.name = 'zone-outline';
  if (!polygon || polygon.length < 2) return g;
  var color = opts.color != null ? opts.color : 0x4fd1c5;
  var width = opts.width != null ? opts.width : 4;
  var y = opts.y != null ? opts.y : 0.12;
  var loop = polygon.slice(); loop.push(polygon[0]);

  var ribbonMat = new THREE.MeshStandardMaterial({
    color: new THREE.Color(color), emissive: new THREE.Color(color), emissiveIntensity: 1.4,
    transparent: true, opacity: 0.5, roughness: 0.4, depthWrite: false, blending: THREE.AdditiveBlending
  });
  var ribbon = makeRibbon(loop, width, y, ribbonMat);
  if (ribbon) { ribbon.renderOrder = 2; ribbon.receiveShadow = false; g.add(ribbon); }

  var linePts = loop.map(function (p) { return new THREE.Vector3(p.x, y + 0.05, p.z); });
  var line = new THREE.Line(
    new THREE.BufferGeometry().setFromPoints(linePts),
    new THREE.LineBasicMaterial({ color: new THREE.Color(color), transparent: true, opacity: 0.9, depthWrite: false })
  );
  line.renderOrder = 3; g.add(line);

  var nodeMat = new THREE.MeshStandardMaterial({
    color: new THREE.Color(color), emissive: new THREE.Color(color), emissiveIntensity: 1.8,
    transparent: true, opacity: 0.85, depthWrite: false, blending: THREE.AdditiveBlending
  });
  var nodeGeom = new THREE.SphereGeometry(width * 0.6, 12, 8);
  for (var i = 0; i < polygon.length; i++) {
    var node = new THREE.Mesh(nodeGeom, nodeMat);
    node.position.set(polygon[i].x, y + 0.1, polygon[i].z); node.renderOrder = 3; g.add(node);
  }
  return g;
}

/* ===== 5. makeShadowCatcher — invisible ShadowMaterial plane @ y=0 ===== */
function makeShadowCatcher(opts) {
  opts = opts || {};
  var size = opts.size != null ? opts.size : 4000;
  var sm = new THREE.ShadowMaterial({ opacity: opts.opacity != null ? opts.opacity : 0.28 });
  var plane = new THREE.Mesh(new THREE.PlaneGeometry(size, size), sm);
  plane.rotation.x = -Math.PI / 2; plane.position.y = 0; plane.receiveShadow = true;
  plane.name = 'shadow-catcher';
  return plane;
}

/* ===== 6. spawnZone — plan + outline + meshes + shadow catcher ===== */
function spawnZone(polygon, opts) {
  opts = opts || {};
  var description = populateZone(polygon, opts);
  var group = new THREE.Group(); group.name = 'zone-root';
  group.add(makeShadowCatcher(opts.shadow || {}));
  group.add(makeZoneOutline(polygon, opts.outline || {}));
  group.add(buildZone(description, opts.build || {}));
  return { group: group, description: description };
}
