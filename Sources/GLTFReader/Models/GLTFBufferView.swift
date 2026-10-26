//
//  GLTFBufferView.swift
//  GLTFReader
//
//  One buffer view: a range of a buffer, with the stride between its elements.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// A range of a buffer, and the stride between its elements when they are interleaved.
public struct GLTFBufferView: Decodable, Equatable, Sendable {
    /// The buffer, by index.
    public let buffer: Int
    /// Where the range starts; 0 when absent.
    public let byteOffset: Int?
    /// How long the range is.
    public let byteLength: Int
    /// Bytes from one element to the next when they are interleaved.
    public let byteStride: Int?
    /// The view's name, when it has one.
    public let name: String?
}
