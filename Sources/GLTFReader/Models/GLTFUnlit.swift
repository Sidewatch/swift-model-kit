//
//  GLTFUnlit.swift
//  GLTFReader
//
//  KHR_materials_unlit: an empty object that marks a material as unlit.
//
//  Created by David Sherlock on 10/27/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// `KHR_materials_unlit`, which has no properties: its presence makes the material's colour its base
/// colour (factor × texture × vertex colour), with no lighting.
public struct GLTFUnlit: Decodable, Equatable, Sendable {}
