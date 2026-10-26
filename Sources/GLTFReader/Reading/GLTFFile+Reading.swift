//
//  GLTFFile+Reading.swift
//  GLTFReader
//
//  Reading a glTF or GLB file: the container, the document and every buffer's bytes.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

extension GLTFFile {
    /// The required extensions this reader decodes: quantized attributes are normalised integers,
    /// which ``floats(accessor:)`` reads like any other. Any other required extension is refused.
    public static let decodedExtensions: Set<String> = ["KHR_mesh_quantization"]

    /// Reads the glTF (JSON) or GLB (binary) file at `url`, told apart by the bytes: its document and
    /// every buffer, a buffer beside it read from its folder.
    public static func read(contentsOf url: URL) throws -> GLTFFile {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return try read(data, folder: url.deletingLastPathComponent())
    }

    /// Reads a glTF or GLB file from its bytes; `folder` is where relative URIs are read from (nil
    /// reads none, so only a GLB's own buffer and `data:` URIs are found).
    public static func read(_ data: Data, folder: URL?) throws -> GLTFFile {
        var json = data
        var embedded: Data?
        if GLBContainer.isGLB(data) { (json, embedded) = try GLBContainer.chunks(of: data) }
        let document: GLTFDocument
        do {
            document = try JSONDecoder().decode(GLTFDocument.self, from: json)
        } catch {
            throw GLTFError.notGLTF
        }
        guard document.asset.version.hasPrefix("2.") else { throw GLTFError.unsupportedVersion(document.asset.version) }
        let undecoded = (document.extensionsRequired ?? []).filter { !decodedExtensions.contains($0) }
        guard undecoded.isEmpty else { throw GLTFError.requiredExtensions(undecoded) }
        let buffers = try (document.buffers ?? []).enumerated().map { index, buffer in
            try bytes(of: buffer, index: index, embedded: embedded, folder: folder)
        }
        return GLTFFile(document: document, buffers: buffers, folder: folder)
    }

    /// A buffer's bytes: a GLB's own chunk for the first buffer without a URI, else what its URI names.
    private static func bytes(of buffer: GLTFBuffer, index: Int, embedded: Data?, folder: URL?) throws -> Data {
        let bytes = buffer.uri.map { ResourceURI.data($0, folder: folder) } ?? (index == 0 ? embedded : nil)
        guard let bytes, buffer.byteLength >= 0, bytes.count >= buffer.byteLength else {
            throw GLTFError.unreadableBuffer(index: index, uri: buffer.uri)
        }
        return bytes
    }
}
