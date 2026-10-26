//
//  GLTFInterpolation.swift
//  GLTFReader
//
//  How an animation sampler goes from one key to the next.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// How an animation sampler goes from one key to the next. A cubic spline stores an in-tangent,
/// the value and an out-tangent per key.
public enum GLTFInterpolation: String, Sendable {
    case linear = "LINEAR"
    case step = "STEP"
    case cubicSpline = "CUBICSPLINE"
}
