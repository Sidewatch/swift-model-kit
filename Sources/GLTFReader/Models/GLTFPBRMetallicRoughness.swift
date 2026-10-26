//
//  GLTFPBRMetallicRoughness.swift
//  GLTFReader
//
//  A material's base colour, metalness and roughness.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// A material's base colour (a factor times an optional texture), metalness and roughness (factors
/// times the blue and green channels of `metallicRoughnessTexture`).
public struct GLTFPBRMetallicRoughness: Decodable, Equatable, Sendable {
    /// The base colour, linear RGBA; white when absent.
    public let baseColorFactor: [Float]?
    /// The base colour's texture, multiplied by the factor.
    public let baseColorTexture: GLTFTextureInfo?
    /// Metalness, 0…1; 1 when absent.
    public let metallicFactor: Float?
    /// Roughness, 0…1; 1 when absent.
    public let roughnessFactor: Float?
    /// Metalness in blue and roughness in green, scaled by the factors.
    public let metallicRoughnessTexture: GLTFTextureInfo?
}
