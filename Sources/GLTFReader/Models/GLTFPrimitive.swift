//
//  GLTFPrimitive.swift
//  GLTFReader
//
//  One primitive of a mesh: its vertex attributes, indices, material and topology.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// One drawable part of a mesh: vertex attributes by semantic (`POSITION`, `NORMAL`, `TEXCOORD_0`,
/// `COLOR_0`, `JOINTS_0`, `WEIGHTS_0`…) to accessor indices, its index accessor, its material and
/// its topology (``mode``, triangles when absent).
public struct GLTFPrimitive: Decodable, Equatable, Sendable {
    /// Vertex attributes by semantic, as accessor indices.
    public let attributes: [String: Int]
    /// The accessor of vertex indices; nil draws the vertices in order.
    public let indices: Int?
    /// The material, by index; nil for glTF's default.
    public let material: Int?
    /// The raw topology code; ``GLTFPrimitiveMode`` names it.
    public let mode: Int?
    /// Morph targets: each a set of attribute deltas, by semantic.
    public let targets: [[String: Int]]?
}
