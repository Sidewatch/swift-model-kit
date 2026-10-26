//
//  GLBContainer.swift
//  GLTFReader
//
//  The binary glTF container: a 12-byte header, a JSON chunk and an optional binary chunk.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The binary glTF container: `glTF`, version 2, the total length, then chunks of a length, a type
/// and the bytes — the document as JSON first, its own buffer second. Every read is checked against
/// the bytes there are.
enum GLBContainer {
    /// Whether `data` starts with the container's magic.
    static func isGLB(_ data: Data) -> Bool { data.prefix(4).elementsEqual("glTF".utf8) }

    /// The JSON chunk and, when there is one, the binary chunk.
    static func chunks(of data: Data) throws -> (json: Data, binary: Data?) {
        guard data.count >= 12 else { throw GLTFError.truncated }
        let version = word(data, at: 4)
        guard version == 2 else { throw GLTFError.unsupportedVersion("GLB \(version)") }
        let length = min(Int(word(data, at: 8)), data.count)
        var json: Data?
        var binary: Data?
        var offset = 12
        while offset + 8 <= length {
            let chunkLength = Int(word(data, at: offset))
            let type = word(data, at: offset + 4)
            let start = offset + 8
            guard chunkLength <= length - start else { throw GLTFError.truncated }
            let body = data.subdata(in: data.startIndex + start..<data.startIndex + start + chunkLength)
            if type == jsonChunk, json == nil { json = body }
            if type == binaryChunk, binary == nil { binary = body }
            offset = start + chunkLength
        }
        guard let json else { throw GLTFError.truncated }
        return (json, binary)
    }

    private static let jsonChunk: UInt32 = 0x4E4F_534A
    private static let binaryChunk: UInt32 = 0x004E_4942

    /// The little-endian 32-bit word at `offset`, which the caller has checked is in range.
    private static func word(_ data: Data, at offset: Int) -> UInt32 {
        data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self).littleEndian }
    }
}
