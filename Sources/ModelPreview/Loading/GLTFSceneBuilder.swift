//
//  GLTFSceneBuilder.swift
//  ModelPreview
//
//  A SceneKit scene built from a read glTF file: its nodes, meshes, materials and animations.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation
import GLTFReader
import SceneKit

/// Builds a SceneKit scene from a read glTF file: the node hierarchy with each node's transform,
/// every mesh primitive as geometry (`+Geometry`), its physically based materials and textures
/// (`+Materials`) and its first animation clip, playing (`+Animations`). A skinned mesh is shown in
/// its bind pose. Every index the file gives is checked; a bad one is a `GLTFError`, never a trap.
final class GLTFSceneBuilder {
    let file: GLTFFile
    /// Built nodes by glTF index, for animation targets.
    var nodes: [Int: SCNNode] = [:]
    /// Built materials by glTF index: a material used by many primitives is built once.
    var materials: [Int: SCNMaterial] = [:]
    /// Decoded images by glTF index; nil when an image could not be decoded.
    var images: [Int: CGImage?] = [:]
    /// Nodes being built, to refuse a hierarchy that is its own ancestor.
    private var building: Set<Int> = []

    init(file: GLTFFile) { self.file = file }

    /// The scene, and how many animation clips the file has (the first one plays).
    static func scene(from file: GLTFFile) throws -> (scene: SCNScene, animations: Int) {
        let builder = GLTFSceneBuilder(file: file)
        let scene = SCNScene()
        for index in file.rootNodes { scene.rootNode.addChildNode(try builder.node(index)) }
        try builder.animate()
        return (scene, file.document.animations?.count ?? 0)
    }

    /// Node `index` with its transform, mesh and children.
    func node(_ index: Int) throws -> SCNNode {
        guard let nodes = file.document.nodes, nodes.indices.contains(index) else { throw GLTFError.outOfRange("Node \(index)") }
        guard !building.contains(index) else { throw GLTFError.outOfRange("Node \(index), its own ancestor,") }
        if let built = self.nodes[index] { return built }
        building.insert(index)
        defer { building.remove(index) }
        let source = nodes[index]
        let node = SCNNode()
        node.name = source.name
        Self.applyTransform(of: source, to: node)
        if let meshIndex = source.mesh { try attachMesh(meshIndex, to: node) }
        for child in source.children ?? [] { node.addChildNode(try self.node(child)) }
        self.nodes[index] = node
        return node
    }

    /// A node's matrix (column by column), else its translation, rotation (x y z w) and scale.
    static func applyTransform(of source: GLTFNode, to node: SCNNode) {
        if let m = source.matrix, m.count == 16 {
            node.simdTransform = simd_float4x4(
                SIMD4(m[0], m[1], m[2], m[3]), SIMD4(m[4], m[5], m[6], m[7]), SIMD4(m[8], m[9], m[10], m[11]),
                SIMD4(m[12], m[13], m[14], m[15]))
            return
        }
        if let t = source.translation, t.count == 3 { node.simdPosition = SIMD3(t[0], t[1], t[2]) }
        if let r = source.rotation, r.count == 4 { node.simdOrientation = simd_quatf(ix: r[0], iy: r[1], iz: r[2], r: r[3]) }
        if let s = source.scale, s.count == 3 { node.simdScale = SIMD3(s[0], s[1], s[2]) }
    }

    /// A mesh's primitives on `node`: one primitive is the node's geometry, several are child nodes
    /// (SceneKit draws one geometry per node).
    private func attachMesh(_ index: Int, to node: SCNNode) throws {
        guard let meshes = file.document.meshes, meshes.indices.contains(index) else { throw GLTFError.outOfRange("Mesh \(index)") }
        let geometries = try meshes[index].primitives.compactMap { try geometry(for: $0) }
        if geometries.count == 1 {
            node.geometry = geometries[0]
        } else {
            for geometry in geometries { node.addChildNode(SCNNode(geometry: geometry)) }
        }
    }
}
