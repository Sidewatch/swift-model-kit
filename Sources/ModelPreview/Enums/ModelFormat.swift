//
//  ModelFormat.swift
//  ModelPreview
//
//  The 3D model formats a preview opens.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// A 3D model format, by its file extension. glTF and GLB are read by this package's `GLTFReader`;
/// macOS reads the rest (SceneKit and Model I/O).
public enum ModelFormat: String, CaseIterable, Sendable {
    case usdz
    case usd
    case usda
    case usdc
    case obj
    case stl
    case ply
    case abc
    case dae
    case scn
    case gltf
    case glb
}
