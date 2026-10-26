//
//  GLTFWebPTexture.swift
//  GLTFReader
//
//  EXT_texture_webp: the WebP image a texture uses when the reader can decode one.
//
//  Created by David Sherlock on 10/27/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// `EXT_texture_webp`: the WebP image a reader that decodes WebP uses; the texture's own `source`
/// is the PNG or JPEG fallback, if it has one.
public struct GLTFWebPTexture: Decodable, Equatable, Sendable {
    /// The WebP image, by index.
    public let source: Int?
}
