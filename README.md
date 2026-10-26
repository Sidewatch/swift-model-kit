# Swift Model Kit

3D models, shown: every format macOS reads and glTF, which it does not, loaded into a SceneKit scene that
stands Y up, measured, drawn as a thumbnail, and shown in a view you turn with the mouse.

## Features

- **glTF 2.0 and GLB, read here and checked against the specification** — `GLTFReader`: the JSON or binary
  container, buffers from the GLB chunk, `data:` URIs or files beside the model (never outside its folder),
  accessors in every component type, normalised, interleaved, sparse or padded matrices, every range checked
  before a byte is read; tested on Khronos's sample models and validator as well as its own
- **Drawn as the spec says** — flat normals when a file has none, the base colour factor before lighting,
  `OPAQUE`, `MASK` and `BLEND`, emission by its factor, morph targets at their default weights, animation
  clamped outside its keys with steps and cubic splines; `KHR_materials_unlit`,
  `KHR_materials_emissive_strength`, `KHR_texture_transform`, `EXT_texture_webp` and `KHR_mesh_quantization`
- **Every format in one call** — `ModelLoader.load(contentsOf:)`: USDZ, USD, USDA, USDC, OBJ, STL, PLY,
  Alembic, Collada and SceneKit through macOS; glTF and GLB built by this package with their physically
  based materials, textures and first animation clip
- **Y up, always** — a file that says it is Z up is turned (USD, Collada); an STL, Z up by convention and
  silent about it, is turned too
- **Facts** — `ModelFacts`: meshes, vertices, triangles, materials, textures, animations, size
- **Thumbnails** — `ModelThumbnailer`: the model drawn off screen, framed and lit as the view shows it
- **A view to look with** — `ModelSceneView`: drag to turn it on a turntable, scroll or pinch to zoom, pan,
  double-click to frame it again; its animation plays
- **No dependencies** — Foundation, SceneKit, Model I/O and ImageIO

## Requirements

- macOS 14+
- Swift 6.2+ (Swift 6 language mode)

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/Sidewatch/swift-model-kit.git", from: "0.1.0")
]
```

Two products: `GLTFReader` (Foundation only) and `ModelPreview` (SceneKit and AppKit).

## Usage

```swift
import ModelPreview

let model = try ModelLoader.load(contentsOf: url)      // off the main thread
model.facts.triangles; model.facts.materials; model.facts.size

let thumbnail = ModelThumbnailer.image(of: model, size: CGSize(width: 256, height: 256))

let view = ModelSceneView(frame: bounds)               // on the main thread
view.backgroundColor = .windowBackgroundColor
view.show(model)
view.showsWireframe = true
```

```swift
import GLTFReader

let file = try GLTFFile.read(contentsOf: url)
let positions = try file.floats(accessor: 0)           // VEC3: three floats a vertex
let indices = try file.integers(accessor: 1)
let png = try file.imageData(0)
```

## What it does not do

- Draco and meshopt compressed geometry, Basis Universal textures and GPU instancing: a file that requires one
  is refused with the extension's name (`GLTFError.requiredExtensions`).
- Skinning: a skinned glTF mesh is shown in its bind pose. Morph targets are drawn at their default weights, but
  their weights are not animated.
- The material extensions past metallic-roughness (clearcoat, sheen, transmission, volume, specular and the
  rest), lights and cameras: the base material is drawn, lit by the studio light.
- FBX: nothing on a Mac reads it without a third-party library.

## Licence

MIT. See `LICENSE`.
