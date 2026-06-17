/* Camera-aware placement for player-drawn gnome zones.
 * Normalized points come from the desktop canvas in screen space:
 *   x: 0 left -> 1 right, y: 0 top -> 1 bottom.
 * The gnome renderer uses a tilted perspective camera, so simple linear X/Z
 * mapping cannot land back underneath the user's marker. Instead, cast a ray
 * through the exact screen point and intersect it with the ground plane.
 */
var GnomeProjection = (() => {
  function ndcFromNormalized(point) {
    return {
      x: ((point && Number.isFinite(point.x) ? point.x : 0.5) - 0.5) * 2,
      y: (0.5 - (point && Number.isFinite(point.y) ? point.y : 0.5)) * 2
    };
  }

  function fallbackGroundPoint(point, halfWidth, halfDepth) {
    const x = point && Number.isFinite(point.x) ? point.x : 0.5;
    const y = point && Number.isFinite(point.y) ? point.y : 0.5;
    return {
      x: (x - 0.5) * 2 * (halfWidth || 1),
      z: (y - 0.5) * 2 * (halfDepth || 1)
    };
  }

  function groundPointFromNormalized(point, camera, halfWidth, halfDepth) {
    if (typeof THREE === 'undefined' || !camera || !camera.position) {
      return fallbackGroundPoint(point, halfWidth, halfDepth);
    }

    const ndc = ndcFromNormalized(point);
    camera.updateMatrixWorld(true);
    const origin = camera.position.clone();
    const onRay = new THREE.Vector3(ndc.x, ndc.y, 0.5).unproject(camera);
    const direction = onRay.sub(origin);
    if (Math.abs(direction.y) < 1e-7) {
      return fallbackGroundPoint(point, halfWidth, halfDepth);
    }

    const t = -origin.y / direction.y;
    if (!Number.isFinite(t) || t <= 0) {
      return fallbackGroundPoint(point, halfWidth, halfDepth);
    }

    return {
      x: origin.x + direction.x * t,
      z: origin.z + direction.z * t
    };
  }

  return {
    ndcFromNormalized,
    groundPointFromNormalized
  };
})();
