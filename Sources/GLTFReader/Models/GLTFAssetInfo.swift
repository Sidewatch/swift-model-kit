//
//  GLTFAssetInfo.swift
//  GLTFReader
//
//  The document's `asset` object: the glTF version and the tool that wrote it.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The document's `asset` object.
public struct GLTFAssetInfo: Decodable, Equatable, Sendable {
    /// The glTF version, `2.0` for every file this reader takes.
    public let version: String
    /// The tool that wrote the file, when it says.
    public let generator: String?
    /// The file's copyright notice, when it has one.
    public let copyright: String?
    /// The lowest glTF version a reader must support to read the file, when it says.
    public let minVersion: String?
}
