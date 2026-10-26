//
//  ModelLoaderTests.swift
//  ModelPreviewTests
//
//  Loading every model format into a Y-up scene with its facts, and the files that must be refused.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import GLTFReader
import SceneKit
import XCTest
@testable import ModelPreview

final class ModelLoaderTests: XCTestCase {
    func testEveryFormatMacOSReadsLoadsWithItsFacts() throws {
        let fixtures = try ModelFixtures(self)
        for name in ["box.usda", "box.usdc", "box.obj", "box.stl", "box.ply", "box.abc"] {
            let model = try ModelLoader.load(contentsOf: fixtures.box(name))
            XCTAssertEqual(model.facts.format, ModelFormat(url: model.url), name)
            XCTAssertGreaterThanOrEqual(model.facts.meshes, 1, name)
            XCTAssertEqual(model.facts.triangles, 12, "\(name): a box is twelve triangles")
            XCTAssertGreaterThan(model.facts.vertices, 0, name)
        }
    }

    /// An STL is Z up by convention and says nothing: it is stood up. An OBJ of the same box is not.
    func testAnSTLIsStoodUpAndAnOBJIsLeftAsItIs() throws {
        let fixtures = try ModelFixtures(self)
        let stl = try ModelLoader.load(contentsOf: fixtures.box("tall.stl", extent: [1, 1, 3]))
        XCTAssertEqual(stl.facts.size.y, 3, accuracy: 0.001, "Z up becomes Y up")
        XCTAssertTrue(stl.facts.stoodUp)
        let obj = try ModelLoader.load(contentsOf: fixtures.box("tall.obj", extent: [1, 1, 3]))
        XCTAssertEqual(obj.facts.size.z, 3, accuracy: 0.001)
        XCTAssertFalse(obj.facts.stoodUp)
    }

    /// A USD file that says it is Z up is stood up by SceneKit, which is asked to.
    func testAUSDFileThatSaysZUpIsStoodUp() throws {
        let fixtures = try ModelFixtures(self)
        let url = try fixtures.file(
            "z-up.usda",
            """
            #usda 1.0
            (
                upAxis = "Z"
            )

            def Mesh "Post"
            {
                int[] faceVertexCounts = [3, 3]
                int[] faceVertexIndices = [0, 1, 2, 0, 2, 3]
                point3f[] points = [(0, 0, 0), (1, 0, 0), (1, 0, 3), (0, 0, 3)]
            }
            """)
        let model = try ModelLoader.load(contentsOf: url)
        XCTAssertEqual(model.facts.size.y, 3, accuracy: 0.001)
    }

    func testAFileThatIsNoModelFormatOrDrawsNothingIsRefused() throws {
        let fixtures = try ModelFixtures(self)
        XCTAssertThrowsError(try ModelLoader.load(contentsOf: fixtures.file("notes.txt", "hello"))) { error in
            XCTAssertEqual(error as? ModelError, .unsupportedFormat("txt"))
        }
        XCTAssertThrowsError(try ModelLoader.load(contentsOf: fixtures.file("empty.obj", "# nothing here\n"))) { error in
            XCTAssertEqual(error as? ModelError, .empty)
        }
    }

    func testAGLTFFileTheReaderRefusesSaysWhy() throws {
        let fixtures = try ModelFixtures(self)
        let url = try fixtures.gltf("draco.gltf", ["extensionsRequired": ["KHR_draco_mesh_compression"]], binary: Data())
        XCTAssertThrowsError(try ModelLoader.load(contentsOf: url)) { error in
            XCTAssertEqual(error as? ModelError, .gltf(.requiredExtensions(["KHR_draco_mesh_compression"])))
        }
    }
}
