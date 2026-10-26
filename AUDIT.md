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
7. Every rule cited to the glTF 2.0 specification or an extension README still holds, and Khronos's sample
   models still load and look like Khronos's screenshots (glTF-Sample-Assets: the feature tests, Duck,
   DamagedHelmet, Fox; the glTF-Validator on the corpus models). The 27 Oct 2026 list is under *History*.

## Known non-issues

- `LoadedModel` is a class marked `@unchecked Sendable`: it is built whole on the loading thread and never
  mutated after, so it can be handed to the main thread; SceneKit guards its own graph while it draws.
- Animations: only the first clip plays (the facts count every clip); morph-weight channels are left out (the
  default weights are applied once, at load); a cubic spline is drawn from its Hermite curve at 30 samples a
  second, at most 100,000 a track.
- SceneKit hands a surface shader a texture's and a vertex colour's texels premultiplied by their alpha but a
  plain colour straight (measured 27 Oct 2026): a material's diffuse is therefore only ever its texture or
  opaque white, and the base colour factor is a shader argument (`GLTFSurfaceShader`). Do not put a
  translucent colour in the diffuse slot.
- A primitive without normals gets flat normals by giving each triangle its own corners, so its geometry
  has three vertices a triangle; `ModelFacts.vertices` keeps the file's own count.
- `KHR_texture_transform` follows Khronos's reference renderer, not the README's GLSL listing, whose rotation
  sign is the other way (glTF issue #1563); TextureTransformTest's arrows confirm it.
- The default material (a primitive with none) is counted as a material in the facts, once.
- A skinned mesh is drawn in its bind pose: no `SCNSkinner` is built.
- `ModelFacts.size` is in the file's own units: SceneKit's `convertUnitsToMeters` does not apply a USD file's
  `metersPerUnit`, and the view frames every model to fit anyway.
- SceneKit's own double-click puts the camera back where it was when the scene was shown; `ModelSceneView`
  frames the model again for the view's current shape instead.

## History

- 27 Oct 2026 — checked against the specification, the first time it had been. Sources: the
  glTF 2.0 specification (Khronos registry, 2.0.1), the READMEs of every extension drawn, Khronos's
  glTF-Validator 2.0.0-dev.3.10 (the corpus models: 0 errors, 0 warnings) and 33 of Khronos's sample models
  (glTF-Sample-Assets, 76 files: glTF, GLB, embedded, Draco and quantized variants), rendered and compared
  with Khronos's screenshots. The container, buffer and accessor layer met every rule. Fixed in the builder:
  smooth normals where a file without normals must get flat ones (3.7.2.1); `MASK` blending the texels it
  keeps instead of drawing them opaque, and `OPAQUE` keeping texture alpha (3.9.4); an emissive texture lit
  at full strength whatever its factor, black by default (5.19.8); the base colour factor applied after
  lighting, which tinted emission (5.22.1); a track starting late or ending early not clamped, a one-pose
  clip never applied (3.11), a step missing Core Animation's closing key time, cubic splines losing their
  tangents (Appendix C), rotations not normalised or kept on the short path; default morph weights ignored
  (3.7.4); points and lines without normals lit (3.9.7); the `…_MIPMAP_NEAREST` filters drawn linear. In
  the reader: `minVersion` not read (3.2); MAT2 and MAT3 of 1- and 2-byte components read without their
  column padding (3.6.2.4); sparse substitutions not applied to index accessors (3.6.2.3); a node with two
  parents moved silently (3.5.2, now refused). Safety: a depth cap of 1,000 levels instead of unbounded
  recursion, and a per-file budget of 128 million components. Added: `KHR_materials_unlit`,
  `KHR_materials_emissive_strength`, `KHR_texture_transform`, `EXT_texture_webp`. Khronos's samples: 71 of 76
  loaded before, 73 after (the 3 Draco files are refused by name); TextureTransformTest, MorphPrimitivesTest
  and UnlitTest now match Khronos's screenshots, OrientationTest's arrows all hit their targets. Tests 28 →
  55, each rule's test shown to fail on a mutant of it (39 mutants, all caught).

- 26 Oct 2026 — written: `GLTFReader` (13 tests) and `ModelPreview` (15 tests), every test shown to fail on
  a mutant (6 reader mutants, 9 preview mutants). Checked by hand against Sidewatch's corpus rocket in 15
  files: every format loads (3–50 ms) and draws the same textured rocket; the STL and the Z-up USD stand.
