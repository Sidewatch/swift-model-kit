//
//  GLTFTextureInfo.swift
//  GLTFReader
//
//  A material's reference to a texture: which one, which UV set, how strongly.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// A material's reference to a texture: its index, the texture coordinate set it reads, and the
/// normal map's `scale` or the occlusion map's `strength`.
public struct GLTFTextureInfo: Decodable, Equatable, Sendable {
    /// The texture, by index.
    public let index: Int
    /// The texture coordinate set it reads; 0 when absent.
    public let texCoord: Int?
    /// A normal map's scale of X and Y.
    public let scale: Float?
    /// An occlusion map's strength.
    public let strength: Float?
}
