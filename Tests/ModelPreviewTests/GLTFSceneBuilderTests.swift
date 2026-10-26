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
        guard values.count == 18 else {
            return XCTFail("two triangles, each with its own three corners (glTF 3.7.2.1): \(values.count / 3)")
        }
        for i in 0..<6 { XCTAssertEqual(values[i * 3 + 2], 1, accuracy: 0.0001, "counter-clockwise in XY faces +Z") }
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
        let factor = try XCTUnwrap(material.value(forKey: "sw_baseColorFactor") as? NSValue).scnVector4Value
        XCTAssertEqual(
            [factor.x, factor.y, factor.z, factor.w], [1, 0.5, 0.5, 1], "the factor multiplies the texture, in the surface shader")
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

    func testCubicSplineKeysKeepTheirValuesNotTheirTangents() {
        let raw: [Float] = [9, 9, 9, 1, 2, 3, 8, 8, 8, 9, 9, 9, 4, 5, 6, 8, 8, 8]
        XCTAssertEqual(GLTFKeyframeSampling.values(raw, width: 3, keys: 2, cubic: true), [[1, 2, 3], [4, 5, 6]])
        XCTAssertNil(GLTFKeyframeSampling.values([1, 2, 3], width: 3, keys: 2, cubic: false), "too few values for the keys")
    }

    // MARK: - glTF 2.0's rules, each from the specification

    /// A model of `json` around one buffer of `binary`.
    private func model(_ fixtures: ModelFixtures, _ name: String, _ json: [String: Any], _ binary: Data) throws -> LoadedModel {
        try ModelLoader.load(contentsOf: fixtures.gltf(name, json, binary: binary))
    }

    func testTrianglesWithoutNormalsAreFlatAndTheFactsKeepTheFilesVertices() throws {
        let fixtures = try ModelFixtures(self)
        let corners: [Float] = [0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 0, 0, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1]
        let faces: [UInt16] = [0, 2, 1, 0, 3, 2, 4, 5, 6, 4, 6, 7, 0, 1, 5, 0, 5, 4, 2, 3, 7, 2, 7, 6, 1, 2, 6, 1, 6, 5, 0, 4, 7, 0, 7, 3]
        let indexBytes = ModelFixtures.bytes(faces)
        let cube = try model(
            fixtures, "cube.gltf",
            [
                "bufferViews": [
                    ["buffer": 0, "byteOffset": 0, "byteLength": 96], ["buffer": 0, "byteOffset": 96, "byteLength": indexBytes.count],
                ],
                "accessors": [
                    ["bufferView": 0, "componentType": 5126, "count": 8, "type": "VEC3"],
                    ["bufferView": 1, "componentType": 5123, "count": faces.count, "type": "SCALAR"],
                ],
                "meshes": [["primitives": [["attributes": ["POSITION": 0], "indices": 1]]]],
                "nodes": [["mesh": 0, "name": "Cube"]],
            ], ModelFixtures.bytes(corners) + indexBytes)
        let geometry = try XCTUnwrap(cube.scene.rootNode.childNode(withName: "Cube", recursively: true)?.geometry)
        let normals: [Float] = try XCTUnwrap(geometry.sources(for: .normal).first).data.withUnsafeBytes {
            Array($0.bindMemory(to: Float.self))
        }
        guard normals.count == 36 * 3 else { return XCTFail("12 triangles, each with its own corners: \(normals.count / 3) normals") }
        for i in 0..<36 {
            let n = normals[i * 3..<i * 3 + 3].map(abs).sorted()
            XCTAssertEqual(n, [0, 0, 1], "a cube's corner takes its face's normal, never an average (glTF 3.7.2.1)")
        }
        XCTAssertEqual(cube.facts.vertices, 8, "the facts count the file's vertices, not the split corners")
        XCTAssertEqual(cube.facts.triangles, 12)
    }

    func testDefaultMorphWeightsMoveTheMesh() throws {
        let fixtures = try ModelFixtures(self)
        let positions = ModelFixtures.bytes([0, 0, 0, 1, 0, 0, 0, 1, 0] as [Float])
        let deltas = ModelFixtures.bytes([0, 0, 1, 0, 0, 1, 0, 0, 1] as [Float])
        let morphed = try model(
            fixtures, "morph.gltf",
            [
                "bufferViews": [["buffer": 0, "byteOffset": 0, "byteLength": 36], ["buffer": 0, "byteOffset": 36, "byteLength": 36]],
                "accessors": [
                    ["bufferView": 0, "componentType": 5126, "count": 3, "type": "VEC3"],
                    ["bufferView": 1, "componentType": 5126, "count": 3, "type": "VEC3"],
                ],
                "meshes": [["primitives": [["attributes": ["POSITION": 0], "targets": [["POSITION": 1]]]], "weights": [0.5]]],
                "nodes": [["mesh": 0, "name": "MeshWeights"], ["mesh": 0, "name": "NodeWeights", "weights": [1]]],
            ], positions + deltas)
        func depth(_ name: String) throws -> Float {
            let source = try XCTUnwrap(
                morphed.scene.rootNode.childNode(withName: name, recursively: true)?.geometry?.sources(for: .vertex).first)
            let values: [Float] = source.data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
            return values[2]
        }
        XCTAssertEqual(try depth("MeshWeights"), 0.5, "the mesh's default weight moves it half the target (glTF 3.7.4)")
        XCTAssertEqual(try depth("NodeWeights"), 1, "a node's weights win over the mesh's")
    }

    func testPrimitivesThatDrawNothingAreSkipped() throws {
        let fixtures = try ModelFixtures(self)
        let good = ModelFixtures.bytes([0, 0, 0, 1, 0, 0, 0, 1, 0] as [Float])
        // Nine 2D points: 18 floats, which read as 3D would be six points, two triangles.
        let flat = ModelFixtures.bytes((0..<18).map { Float($0 % 3) })
        let broken = ModelFixtures.bytes([0, 0, 0, .nan, 0, 0, 0, 1, 0] as [Float])
        let mixed = try model(
            fixtures, "mixed.gltf",
            [
                "bufferViews": [
                    ["buffer": 0, "byteOffset": 0, "byteLength": 36], ["buffer": 0, "byteOffset": 36, "byteLength": 72],
                    ["buffer": 0, "byteOffset": 108, "byteLength": 36],
                ],
                "accessors": [
                    ["bufferView": 0, "componentType": 5126, "count": 3, "type": "VEC3"],
                    ["bufferView": 1, "componentType": 5126, "count": 9, "type": "VEC2"],
                    ["bufferView": 2, "componentType": 5126, "count": 3, "type": "VEC3"],
                ],
                "meshes": [
                    [
                        "primitives": [
                            ["attributes": ["POSITION": 0]], ["attributes": ["POSITION": 0], "mode": 9], ["attributes": ["POSITION": 1]],
                            ["attributes": ["POSITION": 2]],
                        ]
                    ]
                ],
                "nodes": [["mesh": 0]],
            ], good + flat + broken)
        XCTAssertEqual(mixed.facts.triangles, 1, "an unknown mode, 2D positions and a NaN position draw nothing")
    }

    func testPointsAndLinesWithoutNormalsAreDrawnUnlit() throws {
        let fixtures = try ModelFixtures(self)
        let positions = ModelFixtures.bytes([0, 0, 0, 1, 0, 0, 0, 1, 0] as [Float])
        let points = try model(
            fixtures, "points.gltf",
            [
                "bufferViews": [["buffer": 0, "byteOffset": 0, "byteLength": 36]],
                "accessors": [["bufferView": 0, "componentType": 5126, "count": 3, "type": "VEC3"]],
                "meshes": [["primitives": [["attributes": ["POSITION": 0], "mode": 0]]]],
                "nodes": [["mesh": 0, "name": "Points"]],
            ], positions)
        let material = try XCTUnwrap(points.scene.rootNode.childNode(withName: "Points", recursively: true)?.geometry?.firstMaterial)
        XCTAssertEqual(material.lightingModel, .constant, "glTF 3.9.7")
    }

    func testADeepHierarchyAndANodeWithTwoParentsAreRefused() throws {
        let fixtures = try ModelFixtures(self)
        let depth = GLTFFile.maximumNodeDepth + 10
        let chain: [[String: Any]] = (0..<depth).map { $0 + 1 < depth ? ["children": [$0 + 1]] : ["mesh": 0] }
        let deep = try square(fixtures, "deep.gltf", indices: [0, 1, 2], mode: 4, extra: ["nodes": chain])
        XCTAssertThrowsError(try ModelLoader.load(contentsOf: deep)) { error in
            guard case .gltf(.tooLarge) = error as? ModelError else { return XCTFail("\(error)") }
        }
        let shared: [[String: Any]] = [["children": [2]], ["children": [2]], ["mesh": 0]]
        let url = try square(
            fixtures, "shared.gltf", indices: [0, 1, 2], mode: 4, extra: ["nodes": shared, "scenes": [["nodes": [0, 1]]]])
        XCTAssertThrowsError(try ModelLoader.load(contentsOf: url)) { error in
            guard case .gltf(.malformed) = error as? ModelError else { return XCTFail("\(error)") }
        }
    }

    func testAFileOverItsBudgetIsRefusedBeforeItIsRead() throws {
        let fixtures = try ModelFixtures(self)
        let url = try square(fixtures, "budget.gltf", indices: [0, 1, 2], mode: 4)
        let builder = GLTFSceneBuilder(file: try GLTFFile.read(contentsOf: url), componentBudget: 10)
        XCTAssertThrowsError(try builder.scene()) { error in
            guard case .tooLarge = error as? GLTFError else { return XCTFail("\(error)") }
        }
        XCTAssertNoThrow(try GLTFSceneBuilder(file: GLTFFile.read(contentsOf: url), componentBudget: 100).scene())
    }

    func testATextureTransformAndItsCoordinateSetReachTheTexture() throws {
        let fixtures = try ModelFixtures(self)
        let transform: [String: Any] = ["offset": [0.5, 0.25], "rotation": Double.pi / 2, "scale": [2, 3], "texCoord": 1]
        let material: [String: Any] = [
            "pbrMetallicRoughness": ["baseColorTexture": ["index": 0, "extensions": ["KHR_texture_transform": transform]]]
        ]
        let loaded = try ModelLoader.load(
            contentsOf: fixtures.square(
                "moved.gltf", material: material, texture: ModelFixtures.png(), extra: ["extensionsUsed": ["KHR_texture_transform"]]))
        let diffuse = try XCTUnwrap(
            loaded.scene.rootNode.childNode(withName: "Square", recursively: true)?.geometry?.firstMaterial?.diffuse)
        XCTAssertEqual(diffuse.mappingChannel, 1, "the extension's texCoord overrides the texture's")
        let m = diffuse.contentsTransform
        // u' = cos·sx·u + sin·sy·v + ox, v' = −sin·sx·u + cos·sy·v + oy (Khronos's reference renderer), with a
        // quarter turn: u' = 3v + 0.5, v' = −2u + 0.25.
        for (value, expected) in [(m.m11, 0), (m.m21, 3), (m.m41, 0.5), (m.m12, -2), (m.m22, 0), (m.m42, 0.25)] as [(CGFloat, CGFloat)] {
            XCTAssertEqual(value, expected, accuracy: 0.0001)
        }
    }

    func testAWebPSourceIsUsedWhenItDecodesElseTheTexturesOwn() throws {
        let fixtures = try ModelFixtures(self)
        func dataURI(_ data: Data) -> String { "data:image/png;base64," + data.base64EncodedString() }
        let orange = ModelFixtures.png(red: 255, green: 128, blue: 0, alpha: 255)
        let blue = ModelFixtures.png(red: 0, green: 0, blue: 255, alpha: 255)
        func firstPixel(_ second: String) throws -> [UInt8] {
            let extra: [String: Any] = [
                "images": [["uri": dataURI(orange)], ["uri": second]],
                "textures": [["source": 0, "extensions": ["EXT_texture_webp": ["source": 1]]]],
            ]
            let loaded = try ModelLoader.load(
                contentsOf: fixtures.square(
                    "webp-\(second.count).gltf", material: ["pbrMetallicRoughness": ["baseColorTexture": ["index": 0]]], extra: extra))
            let contents = try XCTUnwrap(
                loaded.scene.rootNode.childNode(withName: "Square", recursively: true)?.geometry?.firstMaterial?.diffuse.contents)
            let image = contents as! CGImage
            let context = CGContext(
                data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            let p = context.data!.assumingMemoryBound(to: UInt8.self)
            return [p[0], p[1], p[2]]
        }
        XCTAssertEqual(try firstPixel(dataURI(blue)), [0, 0, 255], "EXT_texture_webp's source when it decodes")
        XCTAssertEqual(try firstPixel("data:image/webp;base64,AAAA"), [255, 128, 0], "the texture's own source when it does not")
    }

    func testTheMipFilterFollowsTheSampler() {
        XCTAssertEqual(GLTFSceneBuilder.mipFilter(9728), .none, "NEAREST")
        XCTAssertEqual(GLTFSceneBuilder.mipFilter(9729), .none, "LINEAR")
        XCTAssertEqual(GLTFSceneBuilder.mipFilter(9984), .nearest, "NEAREST_MIPMAP_NEAREST")
        XCTAssertEqual(GLTFSceneBuilder.mipFilter(9985), .nearest, "LINEAR_MIPMAP_NEAREST")
        XCTAssertEqual(GLTFSceneBuilder.mipFilter(9986), .linear, "NEAREST_MIPMAP_LINEAR")
        XCTAssertEqual(GLTFSceneBuilder.mipFilter(nil), .linear, "no sampler: auto filtering")
    }

    func testAClipWhoseKeysAreAllAtZeroIsAPose() throws {
        let fixtures = try ModelFixtures(self)
        let positions = ModelFixtures.bytes([0, 0, 0, 1, 0, 0, 0, 1, 0] as [Float])
        let time = ModelFixtures.bytes([0] as [Float])
        let place = ModelFixtures.bytes([5, 6, 7] as [Float])
        let posed = try model(
            fixtures, "pose.gltf",
            [
                "bufferViews": [
                    ["buffer": 0, "byteOffset": 0, "byteLength": 36], ["buffer": 0, "byteOffset": 36, "byteLength": 4],
                    ["buffer": 0, "byteOffset": 40, "byteLength": 12],
                ],
                "accessors": [
                    ["bufferView": 0, "componentType": 5126, "count": 3, "type": "VEC3"],
                    ["bufferView": 1, "componentType": 5126, "count": 1, "type": "SCALAR"],
                    ["bufferView": 2, "componentType": 5126, "count": 1, "type": "VEC3"],
                ],
                "meshes": [["primitives": [["attributes": ["POSITION": 0]]]]],
                "nodes": [["mesh": 0, "name": "Posed"]],
                "animations": [
                    [
                        "samplers": [["input": 1, "output": 2]],
                        "channels": [["sampler": 0, "target": ["node": 0, "path": "translation"]]],
                    ]
                ],
            ], positions + time + place)
        let node = try XCTUnwrap(posed.scene.rootNode.childNode(withName: "Posed", recursively: true))
        XCTAssertEqual(node.simdPosition, SIMD3<Float>(5, 6, 7), "a pose's values hold (glTF 3.11 clamps outside the keys)")
    }
}
