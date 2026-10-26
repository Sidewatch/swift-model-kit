//
//  GLTFMesh.swift
//  GLTFReader
//
//  One mesh: its primitives.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// One mesh: the primitives it is drawn with.
public struct GLTFMesh: Decodable, Equatable, Sendable {
    /// The mesh's name, when it has one.
    public let name: String?
    /// The parts it is drawn with.
    public let primitives: [GLTFPrimitive]
    /// Default morph target weights.
    public let weights: [Float]?
}
