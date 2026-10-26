//
//  GLTFBuffer.swift
//  GLTFReader
//
//  One buffer: its bytes' URI and length.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// One buffer: where its bytes are (a `data:` URI, a path beside the file, or, with no URI, a GLB's
/// own binary chunk) and how many there are.
public struct GLTFBuffer: Decodable, Equatable, Sendable {
    /// Where the bytes are; nil for a GLB's own chunk.
    public let uri: String?
    /// How many bytes the buffer has.
    public let byteLength: Int
    /// The buffer's name, when it has one.
    public let name: String?
}
