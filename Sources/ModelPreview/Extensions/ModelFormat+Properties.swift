//
//  ModelFormat+Properties.swift
//  ModelPreview
//
//  A model format's name, and how its files are read.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

extension ModelFormat {
    /// The format of a file with extension `fileExtension`, in any case; nil for anything else.
    public init?(fileExtension: String) { self.init(rawValue: fileExtension.lowercased()) }

    /// The format of the file at `url`, by its extension.
    public init?(url: URL) { self.init(fileExtension: url.pathExtension) }

    /// The format's name as its tools call it.
    public var displayName: String {
        switch self {
        case .usdz: "USDZ"
        case .usd: "USD"
        case .usda: "USDA"
        case .usdc: "USDC"
        case .obj: "OBJ"
        case .stl: "STL"
        case .ply: "PLY"
        case .abc: "Alembic"
        case .dae: "Collada"
        case .scn: "SceneKit"
        case .gltf: "glTF"
        case .glb: "GLB"
        }
    }

    /// Whether files of this format are text a person can read and an agent can edit: glTF's JSON,
    /// USD's text form, OBJ and Collada. (STL and PLY can be either; this counts them binary.)
    public var isText: Bool { [.gltf, .usda, .obj, .dae].contains(self) }

    /// Whether the file is read by this package rather than by macOS.
    var isGLTF: Bool { self == .gltf || self == .glb }

    /// Whether the format keeps Z up by convention and says nothing about it in the file: STL, the
    /// format of CAD tools and 3D-printing slicers.
    var isZUpByConvention: Bool { self == .stl }
}
