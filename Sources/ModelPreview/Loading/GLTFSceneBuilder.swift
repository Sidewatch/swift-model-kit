//
//  GLTFSceneBuilder.swift
//  ModelPreview
//
//  A read glTF file as a SceneKit scene: nodes, meshes, materials and the first animation.
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
/// its bind pose. Every index the file gives is checked; a bad one is a `GLTFError`, never a trap, and
/// everything read or built counts against ``componentBudget``, so a small file cannot ask for gigabytes.
final class GLTFSceneBuilder {
    let file: GLTFFile
    /// Built nodes by glTF index, for animation targets.
    var nodes: [Int: SCNNode] = [:]
    /// Built materials by glTF index and lighting: a material used by many primitives is built once,
    /// and once more unlit for points and lines that have no normals.
    var materials: [MaterialKey: SCNMaterial] = [:]
    /// Decoded images by glTF index; nil when an image could not be decoded.
    var images: [Int: CGImage?] = [:]
    /// The file's own vertices drawn, for its facts: a primitive split per triangle for flat normals
    /// still counts the vertices the file gave.
    var vertices = 0
    /// The most floats and indices one file may have read and built for it.
    let componentBudget: Int
    /// Accessors read so far, by index: a mesh drawn by several nodes reads its data once.
    private var floatsRead: [Int: [Float]] = [:]
    /// Floats and indices read and built so far, against ``componentBudget``.
    private var componentsSpent = 0
    /// Nodes being built, to refuse a hierarchy that is its own ancestor.
    private var building: Set<Int> = []

    /// The budget of one file: 128 million components, 512 MB of floats.
    static let defaultComponentBudget = 128_000_000

    /// A material by its glTF index (nil for glTF's default) and whether it is drawn unlit.
    struct MaterialKey: Hashable {
        let index: Int?
        let unlit: Bool
    }

    init(file: GLTFFile, componentBudget: Int = defaultComponentBudget) {
        self.file = file
        self.componentBudget = componentBudget
    }

    /// The scene, how many animation clips the file has (the first one plays) and its own vertex count.
    static func scene(from file: GLTFFile) throws -> (scene: SCNScene, animations: Int, vertices: Int) {
        let builder = GLTFSceneBuilder(file: file)
        let scene = try builder.scene()
        return (scene, file.document.animations?.count ?? 0, builder.vertices)
    }

    /// The scene: the root nodes with everything under them, the first clip playing.
    func scene() throws -> SCNScene {
        let scene = SCNScene()
        for index in file.rootNodes { scene.rootNode.addChildNode(try node(index, depth: 0)) }
        try animate()
        return scene
    }

    /// Node `index` with its transform, mesh and children. The hierarchy must be a set of trees
    /// (glTF 3.5.2): a node that is its own ancestor or has two parents is refused, and so is nesting
    /// past ``GLTFFile/maximumNodeDepth``.
    func node(_ index: Int, depth: Int) throws -> SCNNode {
        guard let nodes = file.document.nodes, nodes.indices.contains(index) else { throw GLTFError.outOfRange("Node \(index)") }
        guard !building.contains(index) else { throw GLTFError.outOfRange("Node \(index), its own ancestor,") }
        guard self.nodes[index] == nil else { throw GLTFError.malformed("Node \(index) has more than one parent.") }
        guard depth < GLTFFile.maximumNodeDepth else {
            throw GLTFError.tooLarge("A node hierarchy deeper than \(GLTFFile.maximumNodeDepth.formatted()) levels")
        }
        building.insert(index)
        defer { building.remove(index) }
        let source = nodes[index]
        let node = SCNNode()
        node.name = source.name
        Self.applyTransform(of: source, to: node)
        if let meshIndex = source.mesh { try attachMesh(meshIndex, weights: source.weights, to: node) }
        for child in source.children ?? [] { node.addChildNode(try self.node(child, depth: depth + 1)) }
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

    /// A mesh's primitives on `node`, its morph targets at the node's weights, else the mesh's own
    /// (glTF 3.7.4): one primitive is the node's geometry, several are child nodes (SceneKit draws one
    /// geometry per node).
    private func attachMesh(_ index: Int, weights: [Float]?, to node: SCNNode) throws {
        guard let meshes = file.document.meshes, meshes.indices.contains(index) else { throw GLTFError.outOfRange("Mesh \(index)") }
        let mesh = meshes[index]
        let geometries = try mesh.primitives.compactMap { try geometry(for: $0, weights: weights ?? mesh.weights ?? []) }
        if geometries.count == 1 {
            node.geometry = geometries[0]
        } else {
            for geometry in geometries { node.addChildNode(SCNNode(geometry: geometry)) }
        }
    }

    // MARK: - Reading within the budget

    /// Accessor `index`'s floats, read once, its declared size counted against the budget before a
    /// byte is read.
    func floats(_ index: Int) throws -> [Float] {
        if let read = floatsRead[index] { return read }
        try spend(declaredComponents(of: index))
        let values = try file.floats(accessor: index)
        floatsRead[index] = values
        return values
    }

    /// Accessor `index`'s unsigned integers, its declared size counted against the budget first.
    func integers(_ index: Int) throws -> [UInt32] {
        try spend(declaredComponents(of: index))
        return try file.integers(accessor: index)
    }

    /// The element type of accessor `index`, when it has a known one.
    func accessorType(_ index: Int) -> GLTFAccessorType? {
        file.document.accessors?[safe: index].flatMap { GLTFAccessorType(rawValue: $0.type) }
    }

    /// Counts `count` more components against the budget; past it, the model is too large to show.
    func spend(_ count: Int) throws {
        let (total, overflow) = componentsSpent.addingReportingOverflow(count)
        guard !overflow, total <= componentBudget else { throw GLTFError.tooLarge("The model's data") }
        componentsSpent = total
    }

    /// The components accessor `index` declares (its count × its width); 0 for one the reader will refuse.
    private func declaredComponents(of index: Int) throws -> Int {
        guard let accessor = file.document.accessors?[safe: index], let type = GLTFAccessorType(rawValue: accessor.type) else { return 0 }
        let (count, overflow) = max(accessor.count, 0).multipliedReportingOverflow(by: type.componentCount)
        guard !overflow else { throw GLTFError.tooLarge("Accessor \(index)") }
        return count
    }
}
