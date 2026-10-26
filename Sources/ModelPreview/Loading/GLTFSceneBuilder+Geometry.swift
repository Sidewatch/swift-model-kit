//
//  GLTFSceneBuilder+Geometry.swift
//  ModelPreview
//
//  One glTF mesh primitive as SceneKit geometry: sources, the element, normals and morphs.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation
import GLTFReader
import SceneKit

extension GLTFSceneBuilder {
    /// The geometry of one primitive: positions moved by its morph targets at `weights`, normals, two
    /// texture coordinate sets (glTF's top-left origin is SceneKit's too) and vertex colours; its indices
    /// checked against the vertex count; a fan, a line strip or a loop rewritten as the list SceneKit
    /// draws. Triangles without normals get flat ones, each triangle its own corners (glTF 3.7.2.1); points
    /// and lines without normals are drawn unlit (3.9.7). Nil for a primitive that draws nothing: no
    /// positions, positions that are not 3D or not finite, or a mode glTF does not define.
    func geometry(for primitive: GLTFPrimitive, weights: [Float]) throws -> SCNGeometry? {
        guard let mode = GLTFPrimitiveMode(rawValue: primitive.mode ?? GLTFPrimitiveMode.triangles.rawValue),
            let positionAccessor = primitive.attributes["POSITION"], accessorType(positionAccessor) == .vec3
        else { return nil }
        var positions = try floats(positionAccessor)
        let vertexCount = positions.count / 3
        guard vertexCount > 0 else { return nil }
        var normals = try attribute("NORMAL", of: primitive, width: 3, count: vertexCount)
        try morph(&positions, &normals, targets: primitive.targets ?? [], weights: weights)
        guard positions.allSatisfy(\.isFinite) else { return nil }
        let indices = try primitive.indices.map { try integers($0) } ?? (0..<UInt32(vertexCount)).map { $0 }
        guard indices.allSatisfy({ Int($0) < vertexCount }) else { throw GLTFError.outOfRange("A vertex index") }
        vertices += vertexCount

        var uvs = try (0..<2).compactMap { try attribute("TEXCOORD_\($0)", of: primitive, width: 2, count: vertexCount) }
        var colors = try colorAttribute(of: primitive, count: vertexCount)
        var element = Self.element(indices, mode: mode)
        if normals == nil, [.triangles, .triangleStrip, .triangleFan].contains(mode) {
            let corners = Self.triangles(element).flatMap { [$0.0, $0.1, $0.2] }
            try spend(corners.count * (6 + 2 * uvs.count + (colors?.width ?? 0)))
            positions = Self.gather(positions, width: 3, at: corners)
            uvs = uvs.map { Self.gather($0, width: 2, at: corners) }
            colors = colors.map { (Self.gather($0.values, width: $0.width, at: corners), $0.width) }
            normals = Self.flatNormals(positions)
            element = Self.element((0..<UInt32(corners.count)).map { $0 }, mode: .triangles)
        }

        var sources = [Self.source(positions, semantic: .vertex, width: 3)]
        if let normals { sources.append(Self.source(normals, semantic: .normal, width: 3)) }
        for uv in uvs { sources.append(Self.source(uv, semantic: .texcoord, width: 2)) }
        if let colors { sources.append(Self.source(colors.values, semantic: .color, width: colors.width)) }
        let geometry = SCNGeometry(sources: sources, elements: [element])
        geometry.materials = [try material(primitive.material, unlit: normals == nil)]
        return geometry
    }

    /// An attribute's floats when the primitive has it with `width` components a vertex.
    private func attribute(_ semantic: String, of primitive: GLTFPrimitive, width: Int, count: Int) throws -> [Float]? {
        guard let accessor = primitive.attributes[semantic] else { return nil }
        let values = try floats(accessor)
        return values.count == count * width ? values : nil
    }

    /// `COLOR_0`, RGB or RGBA, with its width.
    private func colorAttribute(of primitive: GLTFPrimitive, count: Int) throws -> (values: [Float], width: Int)? {
        guard let accessor = primitive.attributes["COLOR_0"] else { return nil }
        let values = try floats(accessor)
        for width in [4, 3] where values.count == count * width { return (values, width) }
        return nil
    }

    /// Positions and normals moved by each morph target's deltas times its weight (glTF 3.7.4), the
    /// normals unit length again after.
    private func morph(_ positions: inout [Float], _ normals: inout [Float]?, targets: [[String: Int]], weights: [Float]) throws {
        var moved = normals
        for (target, weight) in zip(targets, weights) where weight != 0 {
            if let accessor = target["POSITION"] {
                let deltas = try floats(accessor)
                if deltas.count == positions.count { for i in positions.indices { positions[i] += weight * deltas[i] } }
            }
            if let accessor = target["NORMAL"], var values = moved {
                let deltas = try floats(accessor)
                if deltas.count == values.count { for i in values.indices { values[i] += weight * deltas[i] } }
                moved = values
            }
        }
        if moved != normals { normals = moved.map(Self.unitVectors) }
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

    /// The vertices at `corners`, `width` floats each, in that order.
    static func gather(_ values: [Float], width: Int, at corners: [Int]) -> [Float] {
        var out = [Float]()
        out.reserveCapacity(corners.count * width)
        for corner in corners { out.append(contentsOf: values[corner * width..<corner * width + width]) }
        return out
    }

    /// Flat normals of an unindexed triangle list: each triangle's face normal at its three corners
    /// (a degenerate triangle's points up).
    static func flatNormals(_ positions: [Float]) -> [Float] {
        func point(_ i: Int) -> SIMD3<Float> { SIMD3(positions[i * 3], positions[i * 3 + 1], positions[i * 3 + 2]) }
        var out = [Float]()
        out.reserveCapacity(positions.count)
        for corner in stride(from: 0, to: positions.count / 3 - 2, by: 3) {
            let face = simd_cross(point(corner + 1) - point(corner), point(corner + 2) - point(corner))
            let length = simd_length(face)
            let unit = length > 0 ? face / length : SIMD3<Float>(0, 1, 0)
            for _ in 0..<3 { out += [unit.x, unit.y, unit.z] }
        }
        return out
    }

    /// Vectors of three floats made unit length (a zero vector points up).
    static func unitVectors(_ values: [Float]) -> [Float] {
        stride(from: 0, to: values.count - 2, by: 3).flatMap { i -> [Float] in
            let v = SIMD3(values[i], values[i + 1], values[i + 2])
            let length = simd_length(v)
            let unit = length > 0 ? v / length : SIMD3<Float>(0, 1, 0)
            return [unit.x, unit.y, unit.z]
        }
    }
}
