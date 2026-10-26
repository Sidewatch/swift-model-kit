//
//  GLTFAccessor.swift
//  GLTFReader
//
//  One accessor: a typed, counted view of a buffer view's bytes.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// A typed view of a buffer view's bytes: `count` elements of `type` (`SCALAR`, `VEC3`, `MAT4`…),
/// each of `componentType` (a ``GLTFComponentType`` code). With no buffer view the elements are
/// zeros, then `sparse` substitutes some of them.
public struct GLTFAccessor: Decodable, Equatable, Sendable {
    /// The buffer view the elements are read from; nil means zeros (then `sparse`).
    public let bufferView: Int?
    /// Where the first element starts in the buffer view; 0 when absent.
    public let byteOffset: Int?
    /// The components' type, a ``GLTFComponentType`` code.
    public let componentType: Int
    /// Integer components stand for 0…1 (unsigned) or -1…1 (signed) values.
    public let normalized: Bool?
    /// How many elements.
    public let count: Int
    /// The elements' shape, a ``GLTFAccessorType`` name (`VEC3`…).
    public let type: String
    /// Each component's least value, which a `POSITION` accessor must give.
    public let min: [Double]?
    /// Each component's greatest value.
    public let max: [Double]?
    /// Elements that differ from the base values.
    public let sparse: GLTFAccessorSparse?
    /// The accessor's name, when it has one.
    public let name: String?
}
