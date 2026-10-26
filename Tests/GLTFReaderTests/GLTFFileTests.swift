//
//  GLTFFileTests.swift
//  GLTFReaderTests
//
//  Reading glTF and GLB files: the containers, buffers by every route, accessors in every shape,
//  and the refusals a hostile or unsupported file earns instead of a trap.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import XCTest
@testable import GLTFReader

final class GLTFFileTests: XCTestCase {
    private let triangle: [Float] = [0, 0, 0, 1, 0, 0, 0, 1, 0]

    /// A triangle: positions (VEC3 floats) and indices (unsigned shorts).
    private func triangleBuilder() -> (GLTFBuilder, positions: Int, indices: Int) {
        var b = GLTFBuilder()
        let positions = b.accessor(view: b.view(GLTFBuilder.floats(triangle)), type: "VEC3", componentType: 5126, count: 3)
        let indices = b.accessor(view: b.view(GLTFBuilder.uint16s([0, 1, 2])), type: "SCALAR", componentType: 5123, count: 3)
        b.json["meshes"] = [["primitives": [["attributes": ["POSITION": positions], "indices": indices]]]]
        b.json["nodes"] = [["mesh": 0]]
        return (b, positions, indices)
    }

    private func temporaryFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("gltf-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    func testATriangleWithItsBufferInADataURIReadsBack() throws {
        let (b, positions, indices) = triangleBuilder()
        let file = try GLTFFile.read(b.gltfWithDataURI(), folder: nil)
        XCTAssertEqual(try file.floats(accessor: positions), triangle)
        XCTAssertEqual(try file.integers(accessor: indices), [0, 1, 2])
        XCTAssertEqual(file.rootNodes, [0], "with no scene, the nodes that are nobody's child")
    }

    func testAGLBsOwnChunkIsItsFirstBuffer() throws {
        let (b, positions, _) = triangleBuilder()
        let file = try GLTFFile.read(b.glb(), folder: nil)
        XCTAssertEqual(try file.floats(accessor: positions), triangle)
    }

    func testABufferBesideTheFileIsReadAndOneOutsideItsFolderIsNot() throws {
        let (b, positions, _) = triangleBuilder()
        let folder = try temporaryFolder()
        let models = folder.appendingPathComponent("models", isDirectory: true)
        try FileManager.default.createDirectory(at: models, withIntermediateDirectories: true)
        try b.binary.write(to: models.appendingPathComponent("my mesh.bin"))
        try b.binary.write(to: folder.appendingPathComponent("outside.bin"))
        func write(_ uri: String) throws -> URL {
            let url = models.appendingPathComponent("model.gltf")
            try JSONSerialization.data(withJSONObject: b.document(bufferURI: uri)).write(to: url)
            return url
        }
        let beside = try GLTFFile.read(contentsOf: write("my%20mesh.bin"))
        XCTAssertEqual(try beside.floats(accessor: positions), triangle, "a percent-encoded name beside the file")
        for uri in ["../outside.bin", "/etc/hosts", "file:///etc/hosts"] {
            XCTAssertThrowsError(try GLTFFile.read(contentsOf: write(uri)), uri) { error in
                XCTAssertEqual(error as? GLTFError, .unreadableBuffer(index: 0, uri: uri))
            }
        }
    }

    func testInterleavedAttributesFollowTheBufferViewsStride() throws {
        var b = GLTFBuilder()
        // position, normal; position, normal — 24 bytes an element.
        let view = b.view(GLTFBuilder.floats([1, 2, 3, 0, 0, 1, 4, 5, 6, 0, 1, 0]), stride: 24)
        let positions = b.accessor(view: view, type: "VEC3", componentType: 5126, count: 2)
        let normals = b.accessor(view: view, type: "VEC3", componentType: 5126, count: 2, offset: 12)
        let file = try GLTFFile.read(b.gltfWithDataURI(), folder: nil)
        XCTAssertEqual(try file.floats(accessor: positions), [1, 2, 3, 4, 5, 6])
        XCTAssertEqual(try file.floats(accessor: normals), [0, 0, 1, 0, 1, 0])
    }

    func testNormalisedIntegersReadAsFractionsAndPlainOnesAsTheirValue() throws {
        var b = GLTFBuilder()
        let bytes = b.accessor(
            view: b.view(Data([0, 51, 255, 0])), type: "VEC2", componentType: 5121, count: 2, extra: ["normalized": true])
        let shorts = b.accessor(
            view: b.view([Int16.min, -32767, 0, 32767].withUnsafeBytes { Data($0) }), type: "SCALAR", componentType: 5122, count: 4,
            extra: ["normalized": true])
        let plain = b.accessor(view: b.view(GLTFBuilder.uint16s([7, 65535])), type: "SCALAR", componentType: 5123, count: 2)
        let file = try GLTFFile.read(b.gltfWithDataURI(), folder: nil)
        XCTAssertEqual(try file.floats(accessor: bytes), [0, 0.2, 1, 0])
        XCTAssertEqual(try file.floats(accessor: shorts), [-1, -1, 0, 1], "the most negative short clamps to -1")
        XCTAssertEqual(try file.floats(accessor: plain), [7, 65535])
    }

    func testSparseSubstitutionsApplyOverZeros() throws {
        var b = GLTFBuilder()
        let indices = b.view(GLTFBuilder.uint16s([1, 3]))
        let values = b.view(GLTFBuilder.floats([5, 6, 7, 8]))
        let sparse = b.accessor(
            view: nil, type: "VEC2", componentType: 5126, count: 4,
            extra: ["sparse": ["count": 2, "indices": ["bufferView": indices, "componentType": 5123], "values": ["bufferView": values]]])
        let file = try GLTFFile.read(b.gltfWithDataURI(), folder: nil)
        XCTAssertEqual(try file.floats(accessor: sparse), [0, 0, 5, 6, 0, 0, 7, 8])
    }

    func testRangesThatRunPastTheirBytesThrowInsteadOfTrapping() throws {
        var b = GLTFBuilder()
        let view = b.view(GLTFBuilder.floats(triangle))
        let tooMany = b.accessor(view: view, type: "VEC3", componentType: 5126, count: 4)
        let pastTheView = b.accessor(view: view, type: "VEC3", componentType: 5126, count: 3, offset: 4)
        let overflowing = b.accessor(view: view, type: "VEC3", componentType: 5126, count: 2, offset: Int.max - 2)
        let huge = b.accessor(view: nil, type: "MAT4", componentType: 5126, count: 1_000_000_000)
        let noSuchView = b.accessor(view: 9, type: "SCALAR", componentType: 5126, count: 1)
        let file = try GLTFFile.read(b.gltfWithDataURI(), folder: nil)
        for index in [tooMany, pastTheView, overflowing, huge, noSuchView, 99] {
            XCTAssertThrowsError(try file.floats(accessor: index), "accessor \(index)") { error in
                guard case .outOfRange = error as? GLTFError else { return XCTFail("\(error)") }
            }
        }
    }

    func testABufferViewPastItsBufferIsOutOfRange() throws {
        var b = GLTFBuilder()
        let positions = b.accessor(view: b.view(GLTFBuilder.floats(triangle)), type: "VEC3", componentType: 5126, count: 3)
        b.bufferViews[0]["byteLength"] = 4096
        let file = try GLTFFile.read(b.gltfWithDataURI(), folder: nil)
        XCTAssertThrowsError(try file.floats(accessor: positions))
    }

    func testACutShortGLBIsRefusedNotRead() throws {
        let (b, _, _) = triangleBuilder()
        let glb = b.glb()
        for length in [8, 20, glb.count - 4] {
            XCTAssertThrowsError(try GLTFFile.read(glb.prefix(length), folder: nil), "\(length) bytes")
        }
    }

    func testRequiredExtensionsItCannotDecodeAreNamed() throws {
        var (b, _, _) = triangleBuilder()
        b.json["extensionsRequired"] = ["KHR_mesh_quantization", "KHR_draco_mesh_compression"]
        XCTAssertThrowsError(try GLTFFile.read(b.gltfWithDataURI(), folder: nil)) { error in
            XCTAssertEqual(error as? GLTFError, .requiredExtensions(["KHR_draco_mesh_compression"]))
        }
    }

    func testOnlyVersionTwoIsReadAndJSONThatIsNotGLTFIsRefused() throws {
        var (b, _, _) = triangleBuilder()
        b.json["asset"] = ["version": "1.0"]
        XCTAssertThrowsError(try GLTFFile.read(b.gltfWithDataURI(), folder: nil)) { error in
            XCTAssertEqual(error as? GLTFError, .unsupportedVersion("1.0"))
        }
        XCTAssertThrowsError(try GLTFFile.read(Data(#"{"name": "package"}"#.utf8), folder: nil)) { error in
            XCTAssertEqual(error as? GLTFError, .notGLTF)
        }
    }

    func testAnImageComesFromItsBufferViewOrItsURI() throws {
        var b = GLTFBuilder()
        let png = Data([0x89, 0x50, 0x4E, 0x47, 1, 2, 3])
        let view = b.view(png)
        b.json["images"] = [["bufferView": view, "mimeType": "image/png"], ["uri": "data:image/png;base64," + png.base64EncodedString()]]
        let file = try GLTFFile.read(b.glb(), folder: nil)
        XCTAssertEqual(try file.imageData(0), png)
        XCTAssertEqual(try file.imageData(1), png)
        XCTAssertThrowsError(try file.imageData(2))
    }

    func testTheSceneShownIsTheChosenOneElseTheFirst() throws {
        var (b, _, _) = triangleBuilder()
        b.json["nodes"] = [["mesh": 0], ["children": [0]], ["mesh": 0]]
        b.json["scenes"] = [["nodes": [1]], ["nodes": [2]]]
        XCTAssertEqual(try GLTFFile.read(b.gltfWithDataURI(), folder: nil).rootNodes, [1])
        b.json["scene"] = 1
        XCTAssertEqual(try GLTFFile.read(b.gltfWithDataURI(), folder: nil).rootNodes, [2])
    }
}
