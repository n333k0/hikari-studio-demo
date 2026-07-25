# 3D / AR model pipeline

How a product photo becomes the `models/<slug>.glb` + `models/<slug>.usdz` pair
behind "Ver en tu espacio".

These scripts are **committed on purpose.** The first version lived in a
`/private/tmp` scratchpad and `docs/site-structure.md` told the next session to
"rewrite it fresh" — which is exactly how the WebP/USDZ bug shipped twice. If
you change the pipeline, change it here.

Requires Blender (4.5.6 LTS at time of writing, `/usr/local/bin/blender`). No
`pip install` — the scripts use Blender's bundled Python, and `pxr` (USD) is
available inside it for verification.

---

## Full pipeline for a new product

**1. Photo → raw GLB.** `mcp__claude_ai_Higgsfield__generate_3d`, model
`tripo_h3_1_image_to_3d`, `auto_size:true texture:true pbr:true`, on the
cleanest single studio photo. ~9 Higgsfield credits (check
`mcp__claude_ai_Higgsfield__balance` first). Use `multi_image_to_3d` instead if
the product genuinely has 2–4 clean angle shots — lifestyle and detail crops
don't count.

**2. Decimate + compress.**

```bash
npx @gltf-transform/cli optimize <raw.glb> <out.glb> \
  --texture-size 1024 --texture-compress webp \
  --simplify-ratio 0.03 --simplify-error 0.001 --compress false
```

Raw Tripo output is ~57 MB / 1M verts; this lands at ~1.8 MB. `--compress false`
matters: it skips Draco/meshopt so Blender can still import the result.

> ⚠️ `--texture-compress webp` is the origin of the "solid violet lamp in
> Quick Look" bug. WebP is right for the GLB (browsers read it, it is ~10×
> smaller than PNG) and fatal in a USDZ (RealityKit cannot decode it and falls
> back to its magenta missing-texture placeholder). Step 3 converts for the
> USDZ only — never skip it.

**3. Scale, hang, export.** Tripo does not know real-world scale (the D70 came
out ~1.08 m when the real product is Ø0.70 m), so the model must be rescaled to
the product's listed dimensions before export.

- **Pendant lamp** → `pendant_hang.py` (below).
- **Floor lamp / anything that really sits on the floor** → `export_usdz.py`.

Ship both files as `models/<slug>.glb` and `models/<slug>.usdz`, and wire them
into the page's `<model-viewer>` with `src` (GLB → Android Scene Viewer / WebXR)
and `ios-src` (USDZ → iPhone Quick Look).

---

## `pendant_hang.py` — make a hanging lamp actually hang

```bash
blender --background --python scripts/3d/pendant_hang.py -- \
  --glb models/ensui-d70.glb \
  --shade tripo_node_980e5331-29eb-4741-bc4e-ed3519151ac7 \
  --cord cord_extension --canopy cord_canopy \
  --shade-bottom 1.29 --ceiling 2.40
```

**The problem it solves.** No web AR runtime has a ceiling anchor or a
placement-height API. `ar-placement` accepts only `floor|wall`; Scene Viewer has
no height intent parameter; Quick Look ignores anchoring hints. All three rest
the model's **lowest bounding-box point** on the detected plane. A pendant
modelled shade-at-the-bottom therefore lands *on the floor* with its cord
sticking up into the air.

The workaround (sanctioned by model-viewer's maintainer, issue #998) is to bake
the drop into the geometry:

```
before                          after
z 1.883  canopy                 z 2.40   canopy (at the ceiling)
z 0.27–1.87  cord (upward)      z 1.56–2.40  cord (84 cm drop)
z 0–0.27  SHADE (on the floor)  z 1.29–1.56  SHADE  ← hangs
                                z 0      1 mm floor anchor
```

**Two traps the anchor has to dodge**, both verified in model-viewer's source:

- It must be **visible**. The bounding box is measured with three.js
  `traverseVisible()`, so a hidden node isn't counted and the trick silently
  collapses back to a floor-resting lamp.
- It must **not** be a flat transparent plane. `findBakedShadows()` treats any
  transparent mesh flatter than `MIN_SHADOW_RATIO` (100:1) as a baked floor
  shadow and *excludes it from the bounding box*. A tiny opaque cube can't trip
  that heuristic.

The script asserts `bbox.min.z == 0` after the transform and exits loudly if the
anchor didn't survive — that assertion is the whole fix's canary.

**Not idempotent.** Always re-run against the pristine GLB, never its own output.

---

## `export_usdz.py` — re-export USDZ with PNG textures

```bash
blender --background --python scripts/3d/export_usdz.py -- --glb models/ensui-d50.glb
```

Geometry untouched; only fixes the WebP→PNG texture codec. Use it for any
product whose USDZ needs regenerating but whose model is otherwise fine.

Rather than unpacking images in place (which writes the original WebP bytes back
to disk), it loads a fresh PNG datablock and swaps the material node references,
preserving each image's colorspace — losing `Non-Color` on the normal/ORM maps
silently wrecks the shading.

---

## Verifying the output

```bash
# 1. no WebP survived into any USDZ — this is the regression that shipped twice
for f in models/*.usdz; do
  printf "%-28s webp=%s png=%s\n" "$f" \
    "$(unzip -l "$f" | grep -c '\.webp')" "$(unzip -l "$f" | grep -c '\.png')"
done   # want webp=0 for every file

# 2. bbox, up-axis and texture paths straight out of the USDZ
blender --background --python-expr '
import sys; from pxr import Usd, UsdGeom, UsdShade
s = Usd.Stage.Open(sys.argv[-1])
print("upAxis", UsdGeom.GetStageUpAxis(s), "mpu", UsdGeom.GetStageMetersPerUnit(s))
c = UsdGeom.BBoxCache(Usd.TimeCode.Default(), [UsdGeom.Tokens.default_])
r = c.ComputeWorldBound(s.GetPseudoRoot()).ComputeAlignedRange()
print("bbox", tuple(r.GetMin()), tuple(r.GetMax()))
' -- models/ensui-d70.usdz

# 3. the 3D preview, in a real browser (needs an HTTP origin — model-viewer
#    fetch()es the GLB, which Chrome blocks over file://)
python3 -m http.server 8899 &
node scripts/screenshot/shoot-ar.mjs \
  http://localhost:8899/productos/ensui-d70/ /abs/path/out.png 390 844 --phone
```

`shoot-ar.mjs` reports the resolved camera orbit/target/FOV, the canvas box and
aspect, whether the modal panel overflows, and any console errors.

**None of this proves AR works.** Real Quick Look / Scene Viewer behaviour can
only be confirmed on physical hardware — see `docs/verification-policy.md`,
"Hardware-dependent features", which requires deploying without being asked so
the user gets a live URL to open on their phone.

---

## Framing the preview

The `<model-viewer>` camera is set declaratively per page. Three things bite:

- **`min-camera-orbit` / `max-camera-orbit` clamp `camera-orbit`.** Setting a
  larger radius without raising the max does nothing — model-viewer's own FAQ
  calls this the #1 cause of "my camera settings have no effect".
- **Use metres, not `%`, for the radius on a hung model.** The `%` basis is a
  bounding sphere centred on `camera-target`; with ~1.3 m of empty space below
  the lamp that sphere is enormous and the percentage becomes meaningless.
- **`.pdp-ar-viewer` needs `height: auto` for its `aspect-ratio` to apply** —
  model-viewer ships `:host { height: 150px }` in its shadow DOM, which
  otherwise wins. Pinning the aspect is what lets one radius look right on both
  a phone and a desktop, since model-viewer derives visible *width* from the
  canvas aspect.
