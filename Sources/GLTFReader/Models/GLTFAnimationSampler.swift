//
//  GLTFAnimationSampler.swift
//  GLTFReader
//
//  One animation sampler: key times, values and the interpolation between them.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// Key times (`input`, seconds) and values (`output`), and how to go between them
/// (``GLTFInterpolation``; linear when absent).
public struct GLTFAnimationSampler: Decodable, Equatable, Sendable {
    /// The accessor of key times, in seconds.
    public let input: Int
    /// The accessor of key values.
    public let output: Int
    /// How to go between keys, a ``GLTFInterpolation`` name; linear when absent.
    public let interpolation: String?
}
