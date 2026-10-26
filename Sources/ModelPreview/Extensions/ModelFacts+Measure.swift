//
//  ModelFacts+Measure.swift
//  ModelPreview
//
//  Counting a scene's meshes, vertices, triangles, materials and textures, and measuring its size.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import SceneKit

extension ModelFacts {
    /// The facts of `scene`: every node with geometry is a mesh, its vertex source's count its
    /// vertices; triangles are counted from each element (a strip's and a polygon's too); materials
    /// and textures (an image, path or URL in any material property) once each however often used.
    static func measure(_ scene: SCNScene, format: ModelFormat, animations: Int, stoodUp: Bool) -> ModelFacts {
        var meshes = 0
        var vertices = 0
        var triangles = 0
        var materials = Set<ObjectIdentifier>()
        var textures = Set<AnyHashable>()
        for node in scene.rootNode.descendants {
            guard let geometry = node.geometry else { continue }
            meshes += 1
            vertices += geometry.sources(for: .vertex).first?.vectorCount ?? 0
            triangles += geometry.elements.reduce(0) { $0 + triangleCount($1) }
            for material in geometry.materials {
                materials.insert(ObjectIdentifier(material))
                for property in textureSlots(of: material) {
                    if let key = textureKey(property.contents) { textures.insert(key) }
                }
            }
        }
        let (low, high) = scene.rootNode.boundingBox
        let size = SIMD3<Float>(Float(high.x - low.x), Float(high.y - low.y), Float(high.z - low.z))
        return ModelFacts(
            format: format, meshes: meshes, vertices: vertices, triangles: triangles, materials: materials.count, textures: textures.count,
            animations: animations, size: meshes > 0 ? size : .zero, stoodUp: stoodUp)
    }

    /// Triangles an element draws: one per primitive of a list or strip, `n − 2` per n-sided polygon.
    static func triangleCount(_ element: SCNGeometryElement) -> Int {
        switch element.primitiveType {
        case .triangles, .triangleStrip: return element.primitiveCount
        case .polygon:
            // A polygon element's data starts with each polygon's vertex count, at the index width.
            let width = element.bytesPerIndex
            guard element.data.count >= element.primitiveCount * width else { return 0 }
            return element.data.withUnsafeBytes { raw in
                (0..<element.primitiveCount).reduce(0) { total, i in
                    let at = i * width
                    let sides: Int
                    switch width {
                    case 1: sides = Int(raw[at])
                    case 2: sides = Int(raw.loadUnaligned(fromByteOffset: at, as: UInt16.self))
                    default: sides = Int(raw.loadUnaligned(fromByteOffset: at, as: UInt32.self))
                    }
                    return total + max(sides - 2, 0)
                }
            }
        default: return 0
        }
    }

    /// The material properties that can hold a texture.
    private static func textureSlots(of material: SCNMaterial) -> [SCNMaterialProperty] {
        [
            material.diffuse, material.normal, material.metalness, material.roughness, material.emission, material.ambientOcclusion,
            material.transparent, material.specular, material.multiply, material.displacement,
        ]
    }

    /// A key that is the same for the same texture: an image or texture object by identity, a path
    /// or URL by value; nil for a colour, a number or nothing.
    private static func textureKey(_ contents: Any?) -> AnyHashable? {
        switch contents {
        case let path as String: return AnyHashable(path)
        case let url as URL: return AnyHashable(url)
        case let image as NSImage: return AnyHashable(ObjectIdentifier(image))
        case let object as AnyObject where CFGetTypeID(object) == CGImage.typeID: return AnyHashable(ObjectIdentifier(object))
        case let object as NSObject where object.className.contains("Texture"): return AnyHashable(ObjectIdentifier(object))
        default: return nil
        }
    }
}
