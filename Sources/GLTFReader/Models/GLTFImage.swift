//
//  GLTFImage.swift
//  GLTFReader
//
//  One image: a URI or a buffer view, and its MIME type.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// One image: a `data:` URI or a path beside the file, or a buffer view with its MIME type.
public struct GLTFImage: Decodable, Equatable, Sendable {
    /// A `data:` URI or a path beside the file.
    public let uri: String?
    /// The buffer view holding the encoded image.
    public let bufferView: Int?
    /// The encoding (`image/png`, `image/jpeg`), given with a buffer view.
    public let mimeType: String?
    /// The image's name, when it has one.
    public let name: String?
}
