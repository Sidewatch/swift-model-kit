//
//  GLTFMaterialExtensions.swift
//  GLTFReader
//
//  The material extensions this reader draws: unlit, and emissive strength.
//
//  Created by David Sherlock on 10/27/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The extensions on a material that this reader draws, by their registered names.
public struct GLTFMaterialExtensions: Decodable, Equatable, Sendable {
    /// `KHR_materials_unlit`: present when the material is drawn with its base colour alone, unlit.
    public let unlit: GLTFUnlit?
    /// `KHR_materials_emissive_strength`: how much brighter than 1.0 the emission is.
    public let emissiveStrength: GLTFEmissiveStrength?

    private enum CodingKeys: String, CodingKey {
        case unlit = "KHR_materials_unlit"
        case emissiveStrength = "KHR_materials_emissive_strength"
    }
}
