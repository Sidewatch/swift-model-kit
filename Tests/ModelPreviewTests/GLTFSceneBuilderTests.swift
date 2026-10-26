//
//  GLTFSceneBuilderTests.swift
//  ModelPreviewTests
//
//  glTF built into SceneKit: geometry in every topology, materials and textures, computed normals,
//  animation, and the hostile files refused rather than drawn.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import GLTFReader
import SceneKit
import XCTest
@testable import ModelPreview

final class GLTFSceneBuilderTests: XCTestCase {
    /// Positions of a unit square in XY, then whatever `extra` bytes follow at offset 48.
    private func square(_ fixtures: ModelFixtures, _ name: String, indices: [UInt16], mode: Int, extra: [String: Any] = [:]) throws -> URL {
        let positions = ModelFixtures.bytes([0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0] as [Float])
        let indexBytes = ModelFixtures.bytes(indices)
        var json: [String: Any] = [
            "bufferViews": [
                ["buffer": 0, "byteOffset": 0, "byteLength": 48], ["buffer": 0, "byteOffset": 48, "byteLength": indexBytes.count],
            ],
            "accessors": [
                ["bufferView": 0, "componentType": 5126, "count": 4, "type": "VEC3"],
                ["bufferView": 1, "componentType": 5123, "count": indices.count, "type": "SCALAR"],
            ],
            "meshes": [["primitives": [["attributes": ["POSITION": 0], "indices": 1, "mode": mode]]]],
            "nodes": [["mesh": 0, "name": "Square"]],
        ]
        json.merge(extra) { $1 }
        return try fixtures.gltf(name, json, binary: positions + indexBytes)
    }

    func testAFanAndAStripBecomeTheTrianglesTheyDraw() throws {
        let fixtures = try ModelFixtures(self)
        let fan = try ModelLoader.load(contentsOf: square(fixtures, "fan.gltf", indices: [0, 1, 2, 3], mode: 6))
        XCTAssertEqual(fan.facts.triangles, 2)
        let strip = try ModelLoader.load(contentsOf: square(fixtures, "strip.gltf", indices: [0, 1, 3, 2], mode: 5))
        XCTAssertEqual(strip.facts.triangles, 2)
        XCTAssertEqual(strip.facts.vertices, 4)
    }

    func testAPrimitiveWithoutNormalsGetsUnitNormalsFacingItsFront() throws {
        let fixtures = try ModelFixtures(self)
        let model = try ModelLoader.load(contentsOf: square(fixtures, "plain.gltf", indices: [0, 1, 2, 0, 2, 3], mode: 4))
        let geometry = try XCTUnwrap(model.scene.rootNode.childNode(withName: "Square", recursively: true)?.geometry)
        let normals = try XCTUnwrap(geometry.sources(for: .normal).first)
        let values: [Float] = normals.data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        XCTAssertEqual(values.count, 12)
        for i in 0..<4 { XCTAssertEqual(values[i * 3 + 2], 1, accuracy: 0.0001, "counter-clockwise in XY faces +Z") }
    }

    func testAVertexIndexPastTheVerticesIsRefused() throws {
        let fixtures = try ModelFixtures(self)
        XCTAssertThrowsError(try ModelLoader.load(contentsOf: square(fixtures, "bad.gltf", indices: [0, 1, 9], mode: 4))) { error in
            guard case .gltf(.outOfRange) = error as? ModelError else { return XCTFail("\(error)") }
        }
    }

    func testANodeThatIsItsOwnAncestorIsRefused() throws {
        let fixtures = try ModelFixtures(self)
        let url = try square(
            fixtures, "cycle.gltf", indices: [0, 1, 2], mode: 4,
            extra: ["nodes": [["mesh": 0, "children": [1]], ["children": [0]]], "scenes": [["nodes": [0]]]])
        XCTAssertThrowsError(try ModelLoader.load(contentsOf: url)) { error in
            guard case .gltf(.outOfRange) = error as? ModelError else { return XCTFail("\(error)") }
        }
    }

    func testAMaterialsColourAndTextureAreItsAndCountedOnce() throws {
        let fixtures = try ModelFixtures(self)
        let png = ModelFixtures.png()
        let positions = ModelFixtures.bytes([0, 0, 0, 1, 0, 0, 0, 1, 0] as [Float])
        let uvs = ModelFixtures.bytes([0, 1, 1, 1, 0, 0] as [Float])
        let url = try fixtures.gltf(
            "textured.gltf",
            [
                "bufferViews": [
                    ["buffer": 0, "byteOffset": 0, "byteLength": 36], ["buffer": 0, "byteOffset": 36, "byteLength": 24],
                    ["buffer": 0, "byteOffset": 60, "byteLength": png.count],
                ],
                "accessors": [
                    ["bufferView": 0, "componentType": 5126, "count": 3, "type": "VEC3"],
                    ["bufferView": 1, "componentType": 5126, "count": 3, "type": "VEC2"],
                ],
                "images": [["bufferView": 2, "mimeType": "image/png"]],
                "textures": [["source": 0]],
                "materials": [
                    [
                        "name": "Painted",
                        "pbrMetallicRoughness": [
                            "baseColorTexture": ["index": 0], "baseColorFactor": [1, 0.5, 0.5, 1], "metallicFactor": 0,
                        ],
                        "doubleSided": true,
                    ]
                ],
                "meshes": [
                    ["primitives": [["attributes": ["POSITION": 0, "TEXCOORD_0": 1], "material": 0]]],
                    ["primitives": [["attributes": ["POSITION": 0], "material": 0]]],
                ],
                "nodes": [["mesh": 0], ["mesh": 1]],
            ], binary: positions + uvs + png)
        let model = try ModelLoader.load(contentsOf: url)
        XCTAssertEqual(model.facts.materials, 1, "two primitives, one material")
        XCTAssertEqual(model.facts.textures, 1)
        let material = try XCTUnwrap(model.scene.rootNode.childNodes.first?.geometry?.firstMaterial)
        XCTAssertEqual(material.name, "Painted")
        XCTAssertEqual(material.lightingModel, .physicallyBased)
        XCTAssertTrue(material.isDoubleSided)
        XCTAssertNotNil(material.diffuse.contents as! CGImage?)
        let factor = try XCTUnwrap(Self.color(material.multiply.contents), "the colour factor multiplies the texture")
        XCTAssertEqual(factor.components ?? [], [1, 0.5, 0.5, 1])
        XCTAssertEqual(factor.colorSpace?.name, CGColorSpace.linearSRGB, "glTF's colours are linear")
        XCTAssertEqual((material.metalness.contents as? NSNumber)?.doubleValue, 0)
    }

    func testTheFirstClipAnimatesItsNodesAndEveryClipIsCounted() throws {
        let fixtures = try ModelFixtures(self)
        let times = ModelFixtures.bytes([0, 1] as [Float])
        let turns = ModelFixtures.bytes([0, 0, 0, 1, 0, 0.7071068, 0, 0.7071068] as [Float])
        let positions = ModelFixtures.bytes([0, 0, 0, 1, 0, 0, 0, 1, 0] as [Float])
        let url = try fixtures.gltf(
            "spin.gltf",
            [
                "bufferViews": [
                    ["buffer": 0, "byteOffset": 0, "byteLength": 36], ["buffer": 0, "byteOffset": 36, "byteLength": 8],
                    ["buffer": 0, "byteOffset": 44, "byteLength": 32],
                ],
                "accessors": [
                    ["bufferView": 0, "componentType": 5126, "count": 3, "type": "VEC3"],
                    ["bufferView": 1, "componentType": 5126, "count": 2, "type": "SCALAR", "min": [0], "max": [1]],
                    ["bufferView": 2, "componentType": 5126, "count": 2, "type": "VEC4"],
                ],
                "meshes": [["primitives": [["attributes": ["POSITION": 0]]]]],
                "nodes": [["mesh": 0, "name": "Spinner"]],
                "animations": [
                    [
                        "name": "Spin", "samplers": [["input": 1, "output": 2]],
                        "channels": [["sampler": 0, "target": ["node": 0, "path": "rotation"]]],
                    ],
                    ["name": "Idle", "samplers": [], "channels": []],
                ],
            ], binary: positions + times + turns)
        let model = try ModelLoader.load(contentsOf: url)
        XCTAssertEqual(model.facts.animations, 2)
        let spinner = try XCTUnwrap(model.scene.rootNode.childNode(withName: "Spinner", recursively: true))
        XCTAssertEqual(spinner.animationKeys.count, 1)
    }

    /// A material property's colour, whichever form SceneKit keeps it in.
    private static func color(_ contents: Any?) -> CGColor? {
        guard let contents else { return nil }
        if let color = contents as? NSColor { return color.cgColor }
        let object = contents as CFTypeRef
        return CFGetTypeID(object) == CGColor.typeID ? unsafeBitCast(object, to: CGColor.self) : nil
    }

    func testCubicSplineKeysKeepTheirValuesNotTheirTangents() {
        let raw: [Float] = [9, 9, 9, 1, 2, 3, 8, 8, 8, 9, 9, 9, 4, 5, 6, 8, 8, 8]
        XCTAssertEqual(GLTFSceneBuilder.keyValues(raw, width: 3, keys: 2, cubic: true), [[1, 2, 3], [4, 5, 6]])
        XCTAssertEqual(GLTFSceneBuilder.keyValues([1, 2, 3], width: 3, keys: 2, cubic: false), [], "too few values for the keys")
    }
}
