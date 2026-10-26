//
//  GLTFAccessorSparse.swift
//  GLTFReader
//
//  The elements of an accessor that differ from its base: their indices and values.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The elements of an accessor that differ from its base values: `count` indices and as many values.
public struct GLTFAccessorSparse: Decodable, Equatable, Sendable {
    /// How many elements differ.
    public let count: Int
    /// Where the differing elements' indices are.
    public let indices: GLTFSparseIndices
    /// Where their values are.
    public let values: GLTFSparseValues
}
