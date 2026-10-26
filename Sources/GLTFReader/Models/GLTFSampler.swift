//
//  GLTFSampler.swift
//  GLTFReader
//
//  How a texture is filtered and wrapped, by OpenGL's codes.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// How a texture is filtered and wrapped, by OpenGL's codes: 9728 nearest, 9729 linear, the
/// mipmap minifications 9984–9987; 33071 clamp, 33648 mirrored repeat, 10497 repeat (the default).
public struct GLTFSampler: Decodable, Equatable, Sendable {
    /// How a texture is magnified, an OpenGL filter code.
    public let magFilter: Int?
    /// How a texture is minified, an OpenGL filter code.
    public let minFilter: Int?
    /// How it wraps across, an OpenGL wrap code.
    public let wrapS: Int?
    /// How it wraps down, an OpenGL wrap code.
    public let wrapT: Int?
}
