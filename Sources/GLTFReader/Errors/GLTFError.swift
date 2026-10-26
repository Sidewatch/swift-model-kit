//
//  GLTFError.swift
//  GLTFReader
//
//  Why a glTF file could not be read.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// Why a glTF file could not be read. A malformed or hostile file is one of these, never a trap.
public enum GLTFError: Error, Equatable, Sendable {
    /// Neither a GLB container nor a glTF document.
    case notGLTF
    /// A version this reader does not take (`asset.version` is not 2.x, or a GLB container is not 2).
    case unsupportedVersion(String)
    /// A GLB container whose header or chunks run past the end of the file.
    case truncated
    /// Extensions the file requires that this reader cannot decode (Draco or meshopt geometry,
    /// Basis Universal textures…), by name.
    case requiredExtensions([String])
    /// A buffer whose bytes could not be had: its index and its URI (nil for a GLB's own chunk).
    case unreadableBuffer(index: Int, uri: String?)
    /// An image whose bytes could not be had: its index and its URI (nil for one in a buffer view).
    case unreadableImage(index: Int, uri: String?)
    /// A reference to an object that does not exist, or a range that runs past its bytes: what it was.
    case outOfRange(String)
}
