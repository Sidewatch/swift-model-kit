//
//  GLTFFile.swift
//  GLTFReader
//
//  A read glTF file: its document and the bytes of every buffer.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// A glTF or GLB file, read: its document, every buffer's bytes in the document's order, and the
/// folder its relative URIs resolve in (nil when it was read from bytes alone).
public struct GLTFFile: Sendable {
    /// The document.
    public let document: GLTFDocument
    /// Every buffer's bytes, in the document's order.
    public let buffers: [Data]
    /// Where relative URIs are read from; nil when the file was read from bytes alone.
    public let folder: URL?

    /// A read file.
    public init(document: GLTFDocument, buffers: [Data], folder: URL?) {
        self.document = document
        self.buffers = buffers
        self.folder = folder
    }
}
