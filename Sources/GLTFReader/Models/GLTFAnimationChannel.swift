//
//  GLTFAnimationChannel.swift
//  GLTFReader
//
//  One animation channel: a sampler driving one property of one node.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// A sampler (by index into its animation's samplers) driving one property of one node.
public struct GLTFAnimationChannel: Decodable, Equatable, Sendable {
    /// The sampler, by index into its animation's samplers.
    public let sampler: Int
    /// The node and property it drives.
    public let target: GLTFAnimationTarget
}
