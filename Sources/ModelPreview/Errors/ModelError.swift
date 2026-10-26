//
//  ModelError.swift
//  ModelPreview
//
//  Why a model could not be shown.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation
import GLTFReader

/// Why a model could not be shown.
public enum ModelError: Error, Equatable, Sendable {
    /// The file's extension is no ``ModelFormat``.
    case unsupportedFormat(String)
    /// macOS could not read the file; what it said.
    case unreadable(String)
    /// The glTF reader refused the file.
    case gltf(GLTFError)
    /// The file was read but draws nothing.
    case empty
}
