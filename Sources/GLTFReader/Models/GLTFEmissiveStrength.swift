//
//  GLTFEmissiveStrength.swift
//  GLTFReader
//
//  KHR_materials_emissive_strength: a multiplier on a material's emission.
//
//  Created by David Sherlock on 10/27/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// `KHR_materials_emissive_strength`: the emission (factor × texture) is multiplied by it.
public struct GLTFEmissiveStrength: Decodable, Equatable, Sendable {
    /// The multiplier; 1 when absent.
    public let emissiveStrength: Float?
}
