//
//  GLTFSparseValues.swift
//  GLTFReader
//
//  Where a sparse accessor's substituted values are stored.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// Where a sparse accessor's substituted values are stored; their type is the accessor's own.
public struct GLTFSparseValues: Decodable, Equatable, Sendable {
    /// The buffer view holding the values.
    public let bufferView: Int
    /// Where they start in it; 0 when absent.
    public let byteOffset: Int?
}
