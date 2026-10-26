//
//  GLTFTextureTransform.swift
//  GLTFReader
//
//  KHR_texture_transform: texture coordinates scaled, rotated and offset.
//
//  Created by David Sherlock on 10/27/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// `KHR_texture_transform`: the texture coordinates are scaled, then rotated, then offset
/// (`translation × rotation × scale` applied to `(u, v, 1)`).
public struct GLTFTextureTransform: Decodable, Equatable, Sendable {
    /// The offset of the coordinates' origin, as a fraction of the texture; `[0, 0]` when absent.
    public let offset: [Float]?
    /// The rotation in radians, counter-clockwise about the origin; 0 when absent.
    public let rotation: Float?
    /// The scale of each coordinate; `[1, 1]` when absent.
    public let scale: [Float]?
    /// The texture coordinate set to read instead of the reference's own.
    public let texCoord: Int?
}
