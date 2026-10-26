//
//  GLTFSkin.swift
//  GLTFReader
//
//  One skin: the joints a mesh bends with and their inverse bind matrices.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The joints (nodes) a skinned mesh bends with, and the matrices that bring its vertices into
/// each joint's space.
public struct GLTFSkin: Decodable, Equatable, Sendable {
    /// The skin's name, when it has one.
    public let name: String?
    /// The joint nodes, by index.
    public let joints: [Int]
    /// The accessor of each joint's inverse bind matrix.
    public let inverseBindMatrices: Int?
    /// The joints' common root, by index.
    public let skeleton: Int?
}
