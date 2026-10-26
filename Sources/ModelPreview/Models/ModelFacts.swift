//
//  ModelFacts.swift
//  ModelPreview
//
//  What a loaded model holds, measured.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// What a loaded model holds, measured from its scene: its parts and how many triangles they draw,
/// its materials and textures, its animations, and its size in the file's own units after it was
/// stood up.
public struct ModelFacts: Equatable, Sendable {
    /// The file's format.
    public let format: ModelFormat
    /// Nodes that draw geometry.
    public let meshes: Int
    /// Vertices, every mesh's together.
    public let vertices: Int
    /// Triangles drawn, every mesh's together.
    public let triangles: Int
    /// Distinct materials.
    public let materials: Int
    /// Distinct textures.
    public let textures: Int
    /// Animation clips (or animated properties, for a format SceneKit reads).
    public let animations: Int
    /// The bounding box's width, height and depth.
    public let size: SIMD3<Float>
    /// The model was turned from Z up to Y up by its format's convention (an STL).
    public let stoodUp: Bool

    /// Facts as measured.
    public init(
        format: ModelFormat, meshes: Int, vertices: Int, triangles: Int, materials: Int, textures: Int, animations: Int, size: SIMD3<Float>,
        stoodUp: Bool
    ) {
        self.format = format
        self.meshes = meshes
        self.vertices = vertices
        self.triangles = triangles
        self.materials = materials
        self.textures = textures
        self.animations = animations
        self.size = size
        self.stoodUp = stoodUp
    }
}
