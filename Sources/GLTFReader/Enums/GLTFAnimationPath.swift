//
//  GLTFAnimationPath.swift
//  GLTFReader
//
//  The node property an animation channel drives.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The node property an animation channel drives.
public enum GLTFAnimationPath: String, Sendable {
    case translation
    case rotation
    case scale
    case weights
}
