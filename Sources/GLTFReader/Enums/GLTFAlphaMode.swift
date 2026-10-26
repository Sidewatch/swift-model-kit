//
//  GLTFAlphaMode.swift
//  GLTFReader
//
//  How a material's alpha is used.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// How a material's alpha is used: ignored, cut off at `alphaCutoff`, or blended.
public enum GLTFAlphaMode: String, Sendable {
    case opaque = "OPAQUE"
    case mask = "MASK"
    case blend = "BLEND"
}
