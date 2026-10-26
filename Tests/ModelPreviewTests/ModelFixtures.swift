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
import ImageIO
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

    /// A 4 × 4 PNG of one sRGB colour with straight (unpremultiplied) alpha, as image editors write
    /// them and ImageIO reads them back.
    static func png(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) -> Data {
        let pixels = Data((0..<16).flatMap { _ in [red, green, blue, alpha] })
        let image = CGImage(
            width: 4, height: 4, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 16, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: CGDataProvider(data: pixels as CFData)!,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    /// A unit square in XY facing +Z, both sides drawn, with texture coordinates, its material from
    /// `material`, its texture (when `texture` is given) image 0, and whatever `extra` sets.
    func square(_ name: String, material: [String: Any], texture: Data? = nil, extra: [String: Any] = [:]) throws -> URL {
        let positions = Self.bytes([0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0] as [Float])
        let uvs = Self.bytes([0, 1, 1, 1, 1, 0, 0, 0] as [Float])
        let indices = Self.bytes([0, 1, 2, 0, 2, 3] as [UInt16])
        var views: [[String: Any]] = [
            ["buffer": 0, "byteOffset": 0, "byteLength": 48], ["buffer": 0, "byteOffset": 48, "byteLength": 32],
            ["buffer": 0, "byteOffset": 80, "byteLength": 12],
        ]
        var json: [String: Any] = [
            "accessors": [
                ["bufferView": 0, "componentType": 5126, "count": 4, "type": "VEC3"],
                ["bufferView": 1, "componentType": 5126, "count": 4, "type": "VEC2"],
                ["bufferView": 2, "componentType": 5123, "count": 6, "type": "SCALAR"],
            ],
            "materials": [material.merging(["doubleSided": true]) { old, _ in old }],
            "meshes": [["primitives": [["attributes": ["POSITION": 0, "TEXCOORD_0": 1], "indices": 2, "material": 0]]]],
            "nodes": [["mesh": 0, "name": "Square"]],
        ]
        var binary = positions + uvs + indices
        if let texture {
            while binary.count % 4 != 0 { binary.append(0) }
            views.append(["buffer": 0, "byteOffset": binary.count, "byteLength": texture.count])
            json["images"] = [["bufferView": 3, "mimeType": "image/png"]]
            json["textures"] = [["source": 0]]
            binary += texture
        }
        json["bufferViews"] = views
        json.merge(extra) { $1 }
        return try gltf(name, json, binary: binary)
    }

    static func bytes(_ floats: [Float]) -> Data { floats.withUnsafeBytes { Data($0) } }
    static func bytes(_ ints: [UInt16]) -> Data { ints.withUnsafeBytes { Data($0) } }
}
