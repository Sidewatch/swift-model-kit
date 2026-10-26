//
//  GLTFPrimitiveMode.swift
//  GLTFReader
//
//  A primitive's topology, by glTF's numeric code.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// A primitive's topology, by glTF's numeric code.
public enum GLTFPrimitiveMode: Int, Sendable {
    case points = 0
    case lines = 1
    case lineLoop = 2
    case lineStrip = 3
    case triangles = 4
    case triangleStrip = 5
    case triangleFan = 6
}
