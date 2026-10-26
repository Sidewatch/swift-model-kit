//
//  GLTFSceneBuilder+Geometry.swift
//  ModelPreview
//
//  One glTF primitive as SceneKit geometry: its vertex attributes, its indices and its topology.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation
import GLTFReader
import SceneKit

extension GLTFSceneBuilder {
    /// The geometry of one primitive: positions, normals (computed when the file has none), two
    /// texture coordinate sets (glTF's top-left origin is SceneKit's too) and vertex colours; its
    /// indices checked against the vertex count; a fan or a line strip or loop rewritten as the list
    /// SceneKit draws. Nil for a primitive without positions.
    func geometry(for primitive: GLTFPrimitive) throws -> SCNGeometry? {
        guard let positionAccessor = primitive.attributes["POSITION"] else { return nil }
        let positions = try file.floats(accessor: positionAccessor)
        let vertexCount = positions.count / 3
        guard vertexCount > 0 else { return nil }
        let indices = try primitive.indices.map { try file.integers(accessor: $0) } ?? (0..<UInt32(vertexCount)).map { $0 }
        guard indices.allSatisfy({ Int($0) < vertexCount }) else { throw GLTFError.outOfRange("A vertex index") }
        let mode = GLTFPrimitiveMode(rawValue: primitive.mode ?? GLTFPrimitiveMode.triangles.rawValue) ?? .triangles
        let element = Self.element(indices, mode: mode)

        var sources = [Self.source(positions, semantic: .vertex, width: 3)]
        if let normals = try attribute("NORMAL", of: primitive, width: 3, count: vertexCount) {
            sources.append(Self.source(normals, semantic: .normal, width: 3))
        } else if mode == .triangles || mode == .triangleStrip || mode == .triangleFan {
            sources.append(Self.source(Self.smoothNormals(positions, triangles: Self.triangles(element)), semantic: .normal, width: 3))
        }
        for set in 0..<2 {
            if let uvs = try attribute("TEXCOORD_\(set)", of: primitive, width: 2, count: vertexCount) {
                sources.append(Self.source(uvs, semantic: .texcoord, width: 2))
            }
        }
        if let colors = try colorAttribute(of: primitive, count: vertexCount) { sources.append(colors) }

        let geometry = SCNGeometry(sources: sources, elements: [element])
        geometry.materials = [try material(primitive.material)]
        return geometry
    }

    /// An attribute's floats when the primitive has it with `width` components a vertex.
    private func attribute(_ semantic: String, of primitive: GLTFPrimitive, width: Int, count: Int) throws -> [Float]? {
        guard let accessor = primitive.attributes[semantic] else { return nil }
        let values = try file.floats(accessor: accessor)
        return values.count == count * width ? values : nil
    }

    /// `COLOR_0`, RGB or RGBA.
    private func colorAttribute(of primitive: GLTFPrimitive, count: Int) throws -> SCNGeometrySource? {
        guard let accessor = primitive.attributes["COLOR_0"] else { return nil }
        let values = try file.floats(accessor: accessor)
        for width in [4, 3] where values.count == count * width { return Self.source(values, semantic: .color, width: width) }
        return nil
    }

    // MARK: - Building blocks

    /// A float source of `width` components a vector.
    static func source(_ values: [Float], semantic: SCNGeometrySource.Semantic, width: Int) -> SCNGeometrySource {
        let data = values.withUnsafeBytes { Data($0) }
        return SCNGeometrySource(
            data: data, semantic: semantic, vectorCount: values.count / width, usesFloatComponents: true, componentsPerVector: width,
            bytesPerComponent: MemoryLayout<Float>.size, dataOffset: 0, dataStride: MemoryLayout<Float>.size * width)
    }

    /// The element that draws `indices` in `mode`: triangle lists and strips, points and lines as
    /// they are; a fan as a list; a line strip or loop as line pairs.
    static func element(_ indices: [UInt32], mode: GLTFPrimitiveMode) -> SCNGeometryElement {
        switch mode {
        case .triangles: return element(Array(indices.prefix(indices.count / 3 * 3)), .triangles, count: indices.count / 3)
        case .triangleStrip: return element(indices, .triangleStrip, count: max(indices.count - 2, 0))
        case .triangleFan:
            let list = indices.count < 3 ? [] : (1..<indices.count - 1).flatMap { [indices[0], indices[$0], indices[$0 + 1]] }
            return element(list, .triangles, count: list.count / 3)
        case .points: return element(indices, .point, count: indices.count)
        case .lines: return element(Array(indices.prefix(indices.count / 2 * 2)), .line, count: indices.count / 2)
        case .lineStrip, .lineLoop:
            var pairs = indices.count < 2 ? [] : (0..<indices.count - 1).flatMap { [indices[$0], indices[$0 + 1]] }
            if mode == .lineLoop, indices.count > 2, let first = indices.first, let last = indices.last { pairs += [last, first] }
            return element(pairs, .line, count: pairs.count / 2)
        }
    }

    private static func element(_ indices: [UInt32], _ type: SCNGeometryPrimitiveType, count: Int) -> SCNGeometryElement {
        SCNGeometryElement(
            data: indices.withUnsafeBytes { Data($0) }, primitiveType: type, primitiveCount: count, bytesPerIndex: MemoryLayout<UInt32>.size
        )
    }

    /// The triangles an element draws, as index triples (a strip unrolled).
    static func triangles(_ element: SCNGeometryElement) -> [(Int, Int, Int)] {
        let indices: [Int] = element.data.withUnsafeBytes { raw in
            (0..<raw.count / 4).map { Int(raw.loadUnaligned(fromByteOffset: $0 * 4, as: UInt32.self)) }
        }
        switch element.primitiveType {
        case .triangles: return stride(from: 0, to: indices.count - 2, by: 3).map { (indices[$0], indices[$0 + 1], indices[$0 + 2]) }
        case .triangleStrip:
            return (0..<max(indices.count - 2, 0)).map { i in
                i % 2 == 0 ? (indices[i], indices[i + 1], indices[i + 2]) : (indices[i + 1], indices[i], indices[i + 2])
            }
        default: return []
        }
    }

    /// Per-vertex normals for a file that has none: each face's normal, weighted by its area, summed
    /// at its vertices.
    static func smoothNormals(_ positions: [Float], triangles: [(Int, Int, Int)]) -> [Float] {
        var normals = [SIMD3<Float>](repeating: .zero, count: positions.count / 3)
        func point(_ i: Int) -> SIMD3<Float> { SIMD3(positions[i * 3], positions[i * 3 + 1], positions[i * 3 + 2]) }
        for (a, b, c) in triangles {
            let face = simd_cross(point(b) - point(a), point(c) - point(a))
            normals[a] += face
            normals[b] += face
            normals[c] += face
        }
        return normals.flatMap { n -> [Float] in
            let length = simd_length(n)
            let unit = length > 0 ? n / length : SIMD3<Float>(0, 1, 0)
            return [unit.x, unit.y, unit.z]
        }
    }
}
