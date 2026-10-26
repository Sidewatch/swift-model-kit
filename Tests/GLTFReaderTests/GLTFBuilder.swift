//
//  GLTFBuilder.swift
//  GLTFReaderTests
//
//  Builds small glTF documents and their buffer in code, for the reader's tests.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// A glTF document under construction: bytes appended to one buffer, buffer views and accessors
/// over them, and whatever else a test sets on `json`.
struct GLTFBuilder {
    var binary = Data()
    var bufferViews: [[String: Any]] = []
    var accessors: [[String: Any]] = []
    var json: [String: Any] = ["asset": ["version": "2.0"]]

    /// Appends `bytes` 4-byte aligned and adds a buffer view over them; returns its index.
    mutating func view(_ bytes: Data, stride: Int? = nil) -> Int {
        while binary.count % 4 != 0 { binary.append(0) }
        var view: [String: Any] = ["buffer": 0, "byteOffset": binary.count, "byteLength": bytes.count]
        if let stride { view["byteStride"] = stride }
        binary.append(bytes)
        bufferViews.append(view)
        return bufferViews.count - 1
    }

    /// Adds an accessor; returns its index.
    mutating func accessor(view: Int?, type: String, componentType: Int, count: Int, offset: Int = 0, extra: [String: Any] = [:]) -> Int {
        var accessor: [String: Any] = ["type": type, "componentType": componentType, "count": count]
        if let view { accessor["bufferView"] = view }
        if offset != 0 { accessor["byteOffset"] = offset }
        accessor.merge(extra) { $1 }
        accessors.append(accessor)
        return accessors.count - 1
    }

    /// The document with its buffer named `uri` (nil: a GLB's own chunk).
    func document(bufferURI uri: String?) -> [String: Any] {
        var doc = json
        var buffer: [String: Any] = ["byteLength": binary.count]
        if let uri { buffer["uri"] = uri }
        doc["buffers"] = [buffer]
        doc["bufferViews"] = bufferViews
        doc["accessors"] = accessors
        return doc
    }

    /// The document as `.gltf` JSON with its buffer inline as a base64 data URI.
    func gltfWithDataURI() -> Data {
        let uri = "data:application/octet-stream;base64," + binary.base64EncodedString()
        return try! JSONSerialization.data(withJSONObject: document(bufferURI: uri))
    }

    /// The document as a GLB: header, JSON chunk (space-padded), binary chunk (zero-padded).
    func glb() -> Data {
        var text = try! JSONSerialization.data(withJSONObject: document(bufferURI: nil))
        while text.count % 4 != 0 { text.append(0x20) }
        var bin = binary
        while bin.count % 4 != 0 { bin.append(0) }
        var out = Data()
        func word(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { out.append(contentsOf: $0) } }
        word(0x4654_6C67)
        word(2)
        word(UInt32(12 + 8 + text.count + 8 + bin.count))
        word(UInt32(text.count))
        word(0x4E4F_534A)
        out.append(text)
        word(UInt32(bin.count))
        word(0x004E_4942)
        out.append(bin)
        return out
    }

    static func floats(_ values: [Float]) -> Data { values.withUnsafeBytes { Data($0) } }
    static func uint16s(_ values: [UInt16]) -> Data { values.withUnsafeBytes { Data($0) } }
}
