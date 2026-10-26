//
//  GLTFTexture.swift
//  GLTFReader
//
//  One texture: an image and the sampler that filters it.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// One texture: an image (`source`) and the sampler that filters and wraps it.
public struct GLTFTexture: Decodable, Equatable, Sendable {
    /// The sampler, by index; repeat and linear filtering when absent.
    public let sampler: Int?
    /// The image, by index.
    public let source: Int?
    /// The texture's name, when it has one.
    public let name: String?
}
