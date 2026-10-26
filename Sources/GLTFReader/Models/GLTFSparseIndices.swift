//
//  GLTFSparseIndices.swift
//  GLTFReader
//
//  Where a sparse accessor's element indices are stored.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// Where a sparse accessor's element indices are stored, and their integer type.
public struct GLTFSparseIndices: Decodable, Equatable, Sendable {
    /// The buffer view holding the indices.
    public let bufferView: Int
    /// Where they start in it; 0 when absent.
    public let byteOffset: Int?
    /// Their unsigned integer type, a ``GLTFComponentType`` code.
    public let componentType: Int
}
