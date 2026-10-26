//
//  GLTFComponentType.swift
//  GLTFReader
//
//  The scalar type of an accessor's components, by glTF's numeric code.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The scalar type of an accessor's components, by glTF's numeric code.
public enum GLTFComponentType: Int, Sendable {
    case byte = 5120
    case unsignedByte = 5121
    case short = 5122
    case unsignedShort = 5123
    case unsignedInt = 5125
    case float = 5126
}
