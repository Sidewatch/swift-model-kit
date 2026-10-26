//
//  GLTFTextureInfoExtensions.swift
//  GLTFReader
//
//  The texture-reference extensions this reader draws: texture transform.
//
//  Created by David Sherlock on 10/27/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The extensions on a material's texture reference that this reader draws, by their registered names.
public struct GLTFTextureInfoExtensions: Decodable, Equatable, Sendable {
    /// `KHR_texture_transform`: an offset, rotation and scale of the texture coordinates.
    public let textureTransform: GLTFTextureTransform?

    private enum CodingKeys: String, CodingKey {
        case textureTransform = "KHR_texture_transform"
    }
}
