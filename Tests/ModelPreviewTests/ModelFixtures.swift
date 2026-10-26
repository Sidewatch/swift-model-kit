//
//  ModelFixtures.swift
//  ModelPreviewTests
//
//  Model files made in the test run: boxes exported by Model I/O, and small glTF documents.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import AppKit
import ModelIO
import XCTest

/// A scratch folder of model files for one test.
struct ModelFixtures {
    let folder: URL

    init(_ test: XCTestCase) throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("models-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let made = folder
        test.addTeardownBlock { try? FileManager.default.removeItem(at: made) }
    }

    /// A box `extent` large exported by Model I/O as `name` (its extension picks the format).
    func box(_ name: String, extent: SIMD3<Float> = [1, 1, 1]) throws -> URL {
        let mesh = MDLMesh(
            boxWithExtent: extent, segments: [1, 1, 1], inwardNormals: false, geometryType: .triangles,
            allocator: MDLMeshBufferDataAllocator())
        let asset = MDLAsset()
        asset.add(mesh)
        let url = folder.appendingPathComponent(name)
        try asset.export(to: url)
        return url
    }

    /// `text` written as `name`.
    func file(_ name: String, _ text: String) throws -> URL {
        let url = folder.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// A glTF document from `json`, with `binary` inline as its one buffer.
    func gltf(_ name: String, _ json: [String: Any], binary: Data) throws -> URL {
        var doc = json
        doc["asset"] = ["version": "2.0"]
        doc["buffers"] = [["uri": "data:application/octet-stream;base64," + binary.base64EncodedString(), "byteLength": binary.count]]
        let url = folder.appendingPathComponent(name)
        try JSONSerialization.data(withJSONObject: doc).write(to: url)
        return url
    }

    /// A 4 × 4 PNG, one colour.
    static func png() -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 4, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.orange.setFill()
        NSRect(x: 0, y: 0, width: 4, height: 4).fill()
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])!
    }

    static func bytes(_ floats: [Float]) -> Data { floats.withUnsafeBytes { Data($0) } }
    static func bytes(_ ints: [UInt16]) -> Data { ints.withUnsafeBytes { Data($0) } }
}
