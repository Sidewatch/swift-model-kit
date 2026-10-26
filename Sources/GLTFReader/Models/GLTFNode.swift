//
//  GLTFNode.swift
//  GLTFReader
//
//  One node of the scene hierarchy: its children, mesh, skin and transform.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// One node of the hierarchy. Its transform is either `matrix` (16 numbers, column by column) or
/// `translation`, `rotation` (a quaternion, x y z w) and `scale`.
public struct GLTFNode: Decodable, Equatable, Sendable {
    /// The node's name, when it has one.
    public let name: String?
    /// Its children, by index.
    public let children: [Int]?
    /// The mesh it draws, by index.
    public let mesh: Int?
    /// The skin its mesh bends with, by index.
    public let skin: Int?
    /// Its transform as 16 numbers, column by column.
    public let matrix: [Float]?
    /// Its translation, x y z.
    public let translation: [Float]?
    /// Its rotation, a unit quaternion x y z w.
    public let rotation: [Float]?
    /// Its scale, x y z.
    public let scale: [Float]?
    /// The mesh's morph target weights, when the node overrides them.
    public let weights: [Float]?
}
