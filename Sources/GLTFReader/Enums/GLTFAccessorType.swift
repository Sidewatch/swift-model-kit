//
//  GLTFAccessorType.swift
//  GLTFReader
//
//  The shape of an accessor's elements: a scalar, a vector or a matrix.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The shape of an accessor's elements.
public enum GLTFAccessorType: String, Sendable {
    case scalar = "SCALAR"
    case vec2 = "VEC2"
    case vec3 = "VEC3"
    case vec4 = "VEC4"
    case mat2 = "MAT2"
    case mat3 = "MAT3"
    case mat4 = "MAT4"
}
