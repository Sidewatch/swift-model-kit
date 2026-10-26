# Swift Model Kit

3D models, shown: glTF read here, every other format through macOS, all loaded into a SceneKit scene that
stands Y up, measured, thumbnailed and shown in an interactive view.

- Modules `GLTFReader` (Foundation only) and `ModelPreview` (SceneKit, AppKit), each in `Sources/<Module>`
  with tests in `Tests/<Module>Tests`; `swift test` is the whole check.
- Swift 6 language mode, tools 6.2, macOS 14+. No dependencies.
- Part of the Sidewatch package family; every package follows the same layout and PR rules.
- **A hostile file is an error, never a trap.** The Quick Look extension hands this whatever Finder points
  at. Every index a glTF file gives is looked up and every byte range checked with overflow-safe
  arithmetic before a byte is read (`AccessorReader`); an accessor is capped at 64 million components; a
  node that is its own ancestor and a vertex index past the vertices are refused. A buffer or image URI is
  read only from the model's own folder or below it.
- **Tests make their models.** Model I/O exports boxes in every format it writes; glTF documents are built
  in code (`GLTFBuilder`, `ModelFixtures`); there are no binary fixtures. Sidewatch's corpus
  (`TestFiles/media/models`) is the by-hand and app-level check.
- SceneKit's texture coordinates start at the image's top, like glTF's: they pass through unflipped
  (measured with a labelled checker). SceneKit's `convertToYUp` turns a Z-up USD file but does not apply
  its units; an STL says nothing and is turned by ``ModelLoader``.

## GLTFReader — `Sources/GLTFReader`

### Module map
- `Models/` — the document as glTF's JSON gives it, one type per object: GLTFDocument, GLTFAssetInfo,
  GLTFScene, GLTFNode, GLTFMesh, GLTFPrimitive, GLTFAccessor (+ GLTFAccessorSparse, GLTFSparseIndices,
  GLTFSparseValues), GLTFBufferView, GLTFBuffer, GLTFMaterial, GLTFPBRMetallicRoughness, GLTFTextureInfo,
  GLTFTexture, GLTFImage, GLTFSampler, GLTFAnimation (+ Channel, Target, Sampler), GLTFSkin; GLTFFile (a
  read file: its document and every buffer's bytes)
- `Enums/` — GLTFComponentType, GLTFAccessorType, GLTFPrimitiveMode, GLTFAlphaMode, GLTFAnimationPath,
  GLTFInterpolation
- `Errors/` — GLTFError
- `Extensions/` — sizes and component counts, error descriptions
- `Reading/` — the engine: `GLTFFile.read` (container, document, buffers, required extensions) and
  `floats(accessor:)`, `integers(accessor:)`, `imageData(_:)`, `rootNodes`
- `Support/` — GLBContainer, ResourceURI (`data:` URIs; files in the model's folder only), AccessorReader

## ModelPreview — `Sources/ModelPreview`

### Module map
- `Enums/` — ModelFormat
- `Models/` — ModelFacts, LoadedModel
- `Errors/` — ModelError
- `Extensions/` — ModelFormat+Properties, ModelFacts+Measure (triangles of lists, strips and polygons;
  materials and textures once each), SCNNode+Descendants, Array+Safe
- `Loading/` — the engine: ModelLoader (the format, SceneKit or glTF, standing an STL up, the facts) and
  GLTFSceneBuilder (+Geometry, +Materials, +Animations)
- `Support/` — ModelFraming (one camera placement for the view and the thumbnail), StudioLighting (a sky
  environment and a key light, applied once)
- `Rendering/` — ModelThumbnailer
- `Views/` — ModelSceneView

## Rules

Read `CONTRIBUTING.md` for the folder layout and the pull-request rules.

@CONTRIBUTING.md

- **Auditing? Read `AUDIT.md` first** — what the last full audit checked and fixed, and the known non-issues
  to skip; extend it, do not redo it.
