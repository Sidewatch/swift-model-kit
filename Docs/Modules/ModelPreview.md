# ModelPreview

3D models, shown with SceneKit: loaded Y up, measured, thumbnailed, and shown in a view you turn.

```swift
let model = try ModelLoader.load(contentsOf: url)    // off the main thread
model.facts                                          // meshes, vertices, triangles, materials, textures, animations, size
ModelThumbnailer.image(of: model, size: CGSize(width: 256, height: 256))
let view = ModelSceneView(frame: bounds)             // main thread
view.show(model)
```

- **Formats** (`ModelFormat`): USDZ, USD, USDA, USDC, OBJ, STL, PLY, Alembic, Collada and SceneKit through
  macOS; glTF and GLB built here (`GLTFSceneBuilder`): node transforms, every primitive topology (fans and
  line strips rewritten as lists), computed normals when the file has none, metallic-roughness materials
  with their textures, samplers and alpha modes, and the first animation clip, looping.
- **Up:** SceneKit is asked to turn a Z-up file Y up (USD and Collada say which way is up); an STL, Z up by
  convention, is turned by the loader (`facts.stoodUp`).
- **Framing and light** are shared by the view and the thumbnail (`ModelFraming`, `StudioLighting`): in front,
  a little above and to the right, the whole model in the narrower field of view; a soft sky to light and
  reflect, and a key light when the file brings none.
- **The view:** drag to turn (a turntable that never rolls), scroll or pinch to zoom, pan, double-click to
  frame the model again for the view's shape; `showsWireframe`; `clear()` lets the model go.
