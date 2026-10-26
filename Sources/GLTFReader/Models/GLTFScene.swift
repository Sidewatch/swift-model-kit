//
//  GLTFScene.swift
//  GLTFReader
//
//  One scene: the nodes at its root.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// One scene: the nodes at its root, by index.
public struct GLTFScene: Decodable, Equatable, Sendable {
    /// The scene's name, when it has one.
    public let name: String?
    /// The nodes at its root, by index.
    public let nodes: [Int]?
}
