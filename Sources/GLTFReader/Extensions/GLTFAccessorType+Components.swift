//
//  GLTFAccessorType+Components.swift
//  GLTFReader
//
//  How many components each accessor type has.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

extension GLTFAccessorType {
    /// Components per element: 1 for a scalar, 4 for a 2×2 matrix, 16 for a 4×4 one.
    public var componentCount: Int {
        switch self {
        case .scalar: 1
        case .vec2: 2
        case .vec3: 3
        case .vec4, .mat2: 4
        case .mat3: 9
        case .mat4: 16
        }
    }
}
