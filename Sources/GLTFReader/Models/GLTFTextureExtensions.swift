//
//  GLTFTextureExtensions.swift
//  GLTFReader
//
//  The texture extensions this reader draws: WebP images.
//
//  Created by David Sherlock on 10/27/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The extensions on a texture that this reader draws, by their registered names.
public struct GLTFTextureExtensions: Decodable, Equatable, Sendable {
    /// `EXT_texture_webp`: a WebP image to use in place of the texture's own source.
    public let webp: GLTFWebPTexture?

    private enum CodingKeys: String, CodingKey {
        case webp = "EXT_texture_webp"
    }
}
