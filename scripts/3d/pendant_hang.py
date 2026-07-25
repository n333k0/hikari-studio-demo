"""Re-author a pendant-lamp GLB so it hangs at ceiling height in AR.

    blender --background --python scripts/3d/pendant_hang.py -- \
        --glb models/ensui-d70.glb \
        --shade tripo_node_980e5331-29eb-4741-bc4e-ed3519151ac7 \
        --cord cord_extension --canopy cord_canopy \
        --shade-bottom 1.85 --ceiling 2.40

Why this exists: no web AR runtime has a ceiling anchor or a placement-height
API — model-viewer's `ar-placement` only accepts floor|wall, Scene Viewer has no
height intent parameter, and AR Quick Look ignores anchoring hints. All three
rest the model's lowest bounding-box point on the detected plane. So a pendant
built shade-at-the-bottom lands *on the floor* with its cord sticking up in the
air, which is exactly the bug this fixes. The sanctioned workaround (model-viewer
issue #998) is to bake the height into the geometry, which is what this does:

    before                          after
    z 1.883  canopy                 z 2.40   canopy (at the ceiling)
    z 0.27-1.87  cord (upward)      z 2.12-2.40  cord
    z 0-0.27  SHADE (on the floor)  z 1.85-2.12  SHADE  <- hangs
                                    z 0      tiny floor anchor

Re-run it against the pristine GLB, not its own output — it is not idempotent.
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _common as C  # noqa: E402

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402


def parse_args():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--glb', required=True, help='input .glb (overwritten in place unless --out)')
    p.add_argument('--out', help='output .glb (default: overwrite --glb)')
    p.add_argument('--usdz', help='output .usdz (default: sibling of --out)')
    p.add_argument('--shade', required=True, help='object name of the shade mesh')
    p.add_argument('--cord', help='object name of the cord mesh (scaled to fit)')
    p.add_argument('--canopy', help='object name of the ceiling-rose mesh')
    p.add_argument('--shade-bottom', type=float, default=1.85,
                   help='height of the shade underside above the floor, metres')
    p.add_argument('--ceiling', type=float, default=2.40,
                   help='assumed ceiling height, metres — the canopy top lands here')
    p.add_argument('--anchor-size', type=float, default=0.001,
                   help='edge length of the floor anchor cube, metres')
    return p.parse_args(argv)


def main():
    args = parse_args()
    glb_in = os.path.abspath(args.glb)
    glb_out = os.path.abspath(args.out or args.glb)
    usdz_out = os.path.abspath(args.usdz or os.path.splitext(glb_out)[0] + '.usdz')

    C.reset_and_import(glb_in)
    C.report_bbox('imported')

    shade = bpy.data.objects.get(args.shade)
    if shade is None:
        sys.exit(f'error: no object named {args.shade!r}. Found: '
                 f'{[o.name for o in bpy.data.objects]}')
    cord = bpy.data.objects.get(args.cord) if args.cord else None
    canopy = bpy.data.objects.get(args.canopy) if args.canopy else None

    # 1. Lift everything so the shade's underside sits at --shade-bottom.
    mn, _ = C.obj_bbox(shade)
    lift = args.shade_bottom - mn.z
    movable = [ob for ob in bpy.data.objects if ob.type == 'MESH']
    for ob in movable:
        ob.location.z += lift
    print(f'[hang] lifted {len(movable)} object(s) by {lift:+.4f} m')

    # 2. Shrink the cord to span from the shade's top up to the ceiling. The cord
    #    was modelled 1.6 m long for a floor-resting lamp; left alone it would now
    #    punch through the ceiling. Scaling the existing cylinder about its own
    #    lower end keeps its material and diameter — rebuilding it would mean
    #    hand-replicating the material.
    _, shade_top = C.obj_bbox(shade)
    if cord is not None:
        cmn, cmx = C.obj_bbox(cord)
        current_len = cmx.z - cmn.z
        target_len = args.ceiling - shade_top.z
        if target_len <= 0:
            sys.exit(f'error: ceiling {args.ceiling} m is below the shade top '
                     f'{shade_top.z:.3f} m — raise --ceiling or lower --shade-bottom')
        factor = target_len / current_len
        pivot = shade_top.z
        cord.location.z = pivot + (cord.location.z - pivot) * factor
        cord.scale.z *= factor
        print(f'[hang] cord {current_len:.4f} m -> {target_len:.4f} m (x{factor:.4f}), '
              f'pivot z={pivot:.4f}')

    # 3. Sit the canopy flush against the ceiling.
    if canopy is not None:
        kmn, kmx = C.obj_bbox(canopy)
        canopy.location.z += args.ceiling - kmx.z
        print(f'[hang] canopy top -> {args.ceiling:.4f} m')

    # 4. The marker that makes "the floor" mean the floor. See _common for the
    #    two traps (must be visible, must not be a flat transparent plane).
    C.add_floor_anchor(size=args.anchor_size)
    print(f'[hang] floor anchor added at origin ({args.anchor_size * 1000:.1f} mm cube)')

    mn, mx = C.report_bbox('re-authored')
    if abs(mn.z) > 1e-4:
        sys.exit(f'error: bbox floor is {mn.z:.6f}, expected 0 — the anchor did not '
                 f'survive, so AR would rest the shade on the floor again')
    if abs(mx.z - args.ceiling) > 1e-3:
        print(f'[warn] bbox top {mx.z:.4f} != ceiling {args.ceiling:.4f}')

    # 5. GLB first (WebP textures, small payload), then swap to PNG for the USDZ.
    C.export_glb(glb_out, keep_webp=True)
    C.images_to_png()
    C.export_usdz(usdz_out)


if __name__ == '__main__':
    main()
