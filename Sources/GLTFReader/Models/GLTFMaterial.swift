//
//  GLTFMaterial.swift
//  GLTFReader
//
//  One material: metallic-roughness colours and textures, and how it blends.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// One physically based material.
public struct GLTFMaterial: Decodable, Equatable, Sendable {
    /// The material's name, when it has one.
    public let name: String?
    /// Its base colour, metalness and roughness.
    public let pbrMetallicRoughness: GLTFPBRMetallicRoughness?
    /// A tangent-space normal map; its `scale` scales the normals' X and Y.
    public let normalTexture: GLTFTextureInfo?
    /// Ambient occlusion in the red channel; its `strength` blends it in.
    public let occlusionTexture: GLTFTextureInfo?
    /// The light it gives off, as a texture.
    public let emissiveTexture: GLTFTextureInfo?
    /// The light it gives off, as an RGB factor.
    public let emissiveFactor: [Float]?
    /// `OPAQUE` (the default), `MASK` or `BLEND`; ``GLTFAlphaMode`` names it.
    public let alphaMode: String?
    /// The alpha under which a `MASK` material draws nothing; 0.5 when absent.
    public let alphaCutoff: Float?
    /// Whether back faces are drawn too.
    public let doubleSided: Bool?
    /// The material extensions this reader draws (unlit, emissive strength).
    public let extensions: GLTFMaterialExtensions?
}
