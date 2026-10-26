//
//  GLTFSurfaceShaderTests.swift
//  ModelPreviewTests
//
//  The base colour and alpha rules of glTF 2.0, read from rendered pixels: the alpha modes, the
//  factor before lighting, emission and its factor, unlit materials.
//
//  Created by David Sherlock on 10/27/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import SceneKit
import XCTest
@testable import ModelPreview

final class GLTFSurfaceShaderTests: XCTestCase {
    private let unlit: [String: Any] = ["KHR_materials_unlit": [String: Any]()]
    private let usesUnlit: [String: Any] = ["extensionsUsed": ["KHR_materials_unlit"]]

    /// The centre pixel of a model's thumbnail over a clear background: sRGB, premultiplied, 0–255.
    private func centre(_ url: URL) throws -> [Int] {
        let model = try ModelLoader.load(contentsOf: url)
        let image = try XCTUnwrap(ModelThumbnailer.image(of: model, size: CGSize(width: 64, height: 64)))
        let context = try XCTUnwrap(
            CGContext(
                data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let (w, h) = (CGFloat(image.width), CGFloat(image.height))
        context.draw(image, in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
        let pixel = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        return (0..<4).map { Int(pixel[$0]) }
    }

    private func assertPixel(_ pixel: [Int], _ expected: [Int], tolerance: Int = 4, _ message: String, line: UInt = #line) {
        let close = zip(pixel, expected).allSatisfy { abs($0 - $1) <= tolerance }
        XCTAssertTrue(close, "\(message): \(pixel), expected \(expected)", line: line)
    }

    func testMaskDrawsWhatItKeepsFullyOpaqueInItsOwnColour() throws {
        let fixtures = try ModelFixtures(self)
        let texture = ModelFixtures.png(red: 255, green: 0, blue: 0, alpha: 179)
        let material: [String: Any] = [
            "pbrMetallicRoughness": ["baseColorTexture": ["index": 0]], "alphaMode": "MASK", "alphaCutoff": 0.5, "extensions": unlit,
        ]
        let kept = try centre(fixtures.square("kept.gltf", material: material, texture: texture, extra: usesUnlit))
        assertPixel(kept, [255, 0, 0, 255], "a texel at 0.7 over a 0.5 cutoff is drawn opaque, not blended (glTF 3.9.4)")
        var higher = material
        higher["alphaCutoff"] = 0.8
        let dropped = try centre(fixtures.square("dropped.gltf", material: higher, texture: texture, extra: usesUnlit))
        XCTAssertEqual(dropped[3], 0, "a texel under the cutoff is not drawn")
    }

    func testOpaqueIgnoresAlphaAndBlendKeepsIt() throws {
        let fixtures = try ModelFixtures(self)
        let texture = ModelFixtures.png(red: 255, green: 0, blue: 0, alpha: 128)
        let opaque: [String: Any] = ["pbrMetallicRoughness": ["baseColorTexture": ["index": 0]], "extensions": unlit]
        let drawn = try centre(fixtures.square("opaque.gltf", material: opaque, texture: texture, extra: usesUnlit))
        assertPixel(drawn, [255, 0, 0, 255], "OPAQUE: the texel's colour, fully opaque, its alpha ignored")
        var blend = opaque
        blend["alphaMode"] = "BLEND"
        let blended = try centre(fixtures.square("blend.gltf", material: blend, texture: texture, extra: usesUnlit))
        XCTAssertEqual(blended[3], 128, accuracy: 8, "BLEND keeps the texel's alpha")
        XCTAssertGreaterThan(blended[0], 150, "and its colour")
    }

    func testTheBaseColourFactorTintsTheTextureNotTheEmission() throws {
        let fixtures = try ModelFixtures(self)
        let white = ModelFixtures.png(red: 255, green: 255, blue: 255, alpha: 255)
        let material: [String: Any] = [
            "pbrMetallicRoughness": ["baseColorTexture": ["index": 0], "baseColorFactor": [0, 1, 0, 1], "metallicFactor": 0],
            "emissiveFactor": [1, 0, 0],
        ]
        let pixel = try centre(fixtures.square("tinted.gltf", material: material, texture: white))
        XCTAssertGreaterThan(pixel[0], 200, "the red emission is not multiplied by the green factor: \(pixel)")
        XCTAssertGreaterThan(pixel[1], 60, "the lit surface is green: \(pixel)")
        XCTAssertLessThan(pixel[2], 60, "and only green: the factor takes the texture's white to green: \(pixel)")
    }

    func testAnEmissiveTextureGlowsOnlyByItsFactor() throws {
        let fixtures = try ModelFixtures(self)
        let white = ModelFixtures.png(red: 255, green: 255, blue: 255, alpha: 255)
        var material: [String: Any] = [
            "pbrMetallicRoughness": ["baseColorFactor": [0, 0, 0, 1], "metallicFactor": 0, "roughnessFactor": 1],
            "emissiveTexture": ["index": 0],
        ]
        let dark = try centre(fixtures.square("unscaled.gltf", material: material, texture: white))
        XCTAssertLessThan(dark[0...2].max() ?? 0, 90, "no emissiveFactor is black, so the texture adds nothing (glTF 5.19.8): \(dark)")
        material["emissiveFactor"] = [1, 1, 1]
        let lit = try centre(fixtures.square("scaled.gltf", material: material, texture: white))
        XCTAssertGreaterThan(lit[0...2].min() ?? 0, 200, "with its factor the texture glows: \(lit)")
    }

    func testAnUnlitMaterialIsItsBaseColourExactly() throws {
        let fixtures = try ModelFixtures(self)
        let material: [String: Any] = ["pbrMetallicRoughness": ["baseColorFactor": [0.2, 0.4, 0.6, 1]], "extensions": unlit]
        let url = try fixtures.square("unlit.gltf", material: material, extra: ["extensionsRequired": ["KHR_materials_unlit"]])
        assertPixel(try centre(url), [124, 170, 203, 255], "linear 0.2, 0.4, 0.6 in sRGB, untouched by light")
    }

    func testEmissiveStrengthMultipliesTheEmission() throws {
        let fixtures = try ModelFixtures(self)
        let strength: [String: Any] = ["KHR_materials_emissive_strength": ["emissiveStrength": 3]]
        let plain = try ModelLoader.load(
            contentsOf: fixtures.square("strong.gltf", material: ["emissiveFactor": [1, 0.5, 0], "extensions": strength]))
        let material = try XCTUnwrap(plain.scene.rootNode.childNode(withName: "Square", recursively: true)?.geometry?.firstMaterial)
        XCTAssertEqual(material.emission.intensity, 3)
        let white = ModelFixtures.png(red: 255, green: 255, blue: 255, alpha: 255)
        let textured = try ModelLoader.load(
            contentsOf: fixtures.square(
                "strong-texture.gltf", material: ["emissiveFactor": [1, 0.5, 0], "emissiveTexture": ["index": 0], "extensions": strength],
                texture: white))
        let scaled = try XCTUnwrap(textured.scene.rootNode.childNode(withName: "Square", recursively: true)?.geometry?.firstMaterial)
        let factor = try XCTUnwrap(scaled.value(forKey: "sw_emissiveFactor") as? NSValue).scnVector3Value
        XCTAssertEqual([factor.x, factor.y, factor.z], [3, 1.5, 0])
    }
}
