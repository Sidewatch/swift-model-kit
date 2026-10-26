# Audit log

Last full audit: **26 Oct 2026** — the day the package was written, for Sidewatch's 3D preview (editor tab,
gallery tiles and Quick Look for glTF). Add a dated line under *History* when you audit again, and keep
*Known non-issues* current so the next pass skips them.

## What a full audit checks

1. `swift build` warnings (none allowed) and `swift test` green.
2. Dead code: every `func`, type and property declared once and referenced nowhere in the package or the
   family. Public API is NOT dead because Sidewatch does not call it.
3. Every public declaration documented with `///`.
4. The README's usage sample compiles against the current API.
5. Every read of a glTF file's bytes goes through `AccessorReader` or `GLBContainer`, after the range is
   checked with overflow-safe arithmetic; every index a file gives is looked up through
   `AccessorReader.element` or `Array[safe:]`, never subscripted raw.
6. A URI is read only through `ResourceURI`, which refuses absolute paths, schemes and `../`.

## Known non-issues

- `LoadedModel` is a class marked `@unchecked Sendable`: it is built whole on the loading thread and never
  mutated after, so it can be handed to the main thread; SceneKit guards its own graph while it draws.
- A glTF base colour factor over a texture is applied through SceneKit's `multiply` slot, which multiplies
  after lighting rather than before; the difference is small for a preview and needs no shader.
- Animations: only the first clip plays (the facts count every clip); morph-weight channels are left out;
  a cubic spline keeps its values and loses its tangents (linear between keys).
- A skinned mesh is drawn in its bind pose: no `SCNSkinner` is built.
- `ModelFacts.size` is in the file's own units: SceneKit's `convertUnitsToMeters` does not apply a USD file's
  `metersPerUnit`, and the view frames every model to fit anyway.
- SceneKit's own double-click puts the camera back where it was when the scene was shown; `ModelSceneView`
  frames the model again for the view's current shape instead.

## History

- 26 Oct 2026 — written: `GLTFReader` (13 tests) and `ModelPreview` (15 tests), every test shown to fail on
  a mutant (6 reader mutants, 9 preview mutants). Checked by hand against Sidewatch's corpus rocket in 15
  files: every format loads (3–50 ms) and draws the same textured rocket; the STL and the Z-up USD stand.
