# GLTFReader

glTF 2.0 and GLB files, read: the document, every buffer's bytes, and any accessor's values or image's bytes
on request. Foundation only; nothing is drawn here (`ModelPreview` builds the scene).

```swift
let file = try GLTFFile.read(contentsOf: url)        // .gltf or .glb, told apart by the bytes
file.document.meshes?.count
let positions = try file.floats(accessor: 0)         // normalised, interleaved and sparse handled
let indices = try file.integers(accessor: 1)
let png = try file.imageData(0)                      // from a buffer view or a URI
let roots = file.rootNodes                           // the chosen scene, else the first, else the parentless nodes
```

- **Buffers:** a GLB's binary chunk, a `data:` URI (base64 or percent-encoded), or a relative path read from
  the model's folder or below it. An absolute path, a URL with a scheme and `../` read nothing.
- **Refusals** (`GLTFError`): not glTF; a version other than 2.x or a `minVersion` above 2.0; a GLB cut short;
  an extension the file requires and this reader does not decode (`GLTFFile.decodedExtensions`: quantized
  attributes, unlit materials, emissive strength, texture transforms, WebP textures); a buffer or image that
  cannot be read; an index or byte range out of range; more than a preview takes (`tooLarge`); a file that
  breaks a rule in a way that changes the picture (`malformed`, a node with two parents). A hostile file is one of these, never a trap: every range is
  checked with overflow-safe arithmetic first, and an accessor is capped at 64 million components.
