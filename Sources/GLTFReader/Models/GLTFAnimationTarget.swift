//
//  GLTFAnimationTarget.swift
//  GLTFReader
//
//  What an animation channel drives: a node and a property.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// What a channel drives: a node, and its `translation`, `rotation`, `scale` or morph `weights`
/// (``GLTFAnimationPath`` names them).
public struct GLTFAnimationTarget: Decodable, Equatable, Sendable {
    /// The node driven, by index.
    public let node: Int?
    /// The property driven, a ``GLTFAnimationPath`` name.
    public let path: String
}
