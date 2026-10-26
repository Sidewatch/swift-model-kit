//
//  GLTFKeyframes.swift
//  ModelPreview
//
//  One animated property's key frames, as Core Animation plays them.
//
//  Created by David Sherlock on 10/27/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// One animated property's key frames as a `CAKeyframeAnimation` takes them: key times from 0 to 1
/// over the clip, a value per key, and whether each value holds until the next key (a step) or blends
/// into it. A step has one more key time than values, as Core Animation's discrete mode wants.
struct GLTFKeyframes: Equatable {
    let keyTimes: [Double]
    let values: [[Float]]
    let discrete: Bool
}
