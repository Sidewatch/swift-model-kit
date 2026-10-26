//
//  ModelPresentationTests.swift
//  ModelPreviewTests
//
//  Framing, thumbnails and the interactive view: the whole model in sight, drawn, and back where it
//  opened after a double-click.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import AppKit
import SceneKit
import XCTest
@testable import ModelPreview

final class ModelPresentationTests: XCTestCase {
    /// Every corner of the bounding box lies inside the camera's field of view, whatever the aspect.
    func testTheFramingCameraSeesEveryCornerOfTheModel() throws {
        let fixtures = try ModelFixtures(self)
        let model = try ModelLoader.load(contentsOf: fixtures.box("long.obj", extent: [6, 1, 1]))
        let (low, high) = model.scene.rootNode.boundingBox
        for aspect in [0.5, 1.0, 2.0] as [CGFloat] {
            let (camera, _) = ModelFraming.camera(for: model.scene, aspect: aspect)
            let forward = -camera.simdWorldFront * -1
            let halfVertical = Float(ModelFraming.fieldOfView) * .pi / 360
            let halfHorizontal = atan(tan(halfVertical) * Float(aspect))
            for x in [low.x, high.x] {
                for y in [low.y, high.y] {
                    for z in [low.z, high.z] {
                        let corner = SIMD3<Float>(Float(x), Float(y), Float(z)) - camera.simdWorldPosition
                        let inCamera = simd_inverse(camera.simdWorldTransform) * SIMD4(corner + camera.simdWorldPosition, 1)
                        XCTAssertLessThan(inCamera.z, 0, "in front of the camera")
                        XCTAssertLessThanOrEqual(abs(atan2(inCamera.y, -inCamera.z)), halfVertical, "aspect \(aspect), height")
                        XCTAssertLessThanOrEqual(abs(atan2(inCamera.x, -inCamera.z)), halfHorizontal, "aspect \(aspect), width")
                        _ = forward
                    }
                }
            }
        }
    }

    /// A thumbnail draws the model in the middle and leaves the corners clear.
    func testAThumbnailDrawsTheModelOnAClearBackground() throws {
        let fixtures = try ModelFixtures(self)
        let model = try ModelLoader.load(contentsOf: fixtures.box("box.usda"))
        let image = try XCTUnwrap(ModelThumbnailer.image(of: model, size: CGSize(width: 64, height: 64)))
        let rep = NSBitmapImageRep(cgImage: image)
        XCTAssertGreaterThan(rep.colorAt(x: rep.pixelsWide / 2, y: rep.pixelsHigh / 2)?.alphaComponent ?? 0, 0.9, "the model in the middle")
        XCTAssertLessThan(rep.colorAt(x: 0, y: 0)?.alphaComponent ?? 1, 0.1, "a clear corner")
        XCTAssertNil(model.scene.rootNode.childNode(withName: "Framing camera", recursively: true), "the thumbnail's camera is taken away")
    }

    /// SceneKit's own double-click puts the camera back where it was when shown; this one frames the
    /// model again for the view's shape now, so a view made tall since still shows all of a wide model.
    @MainActor
    func testTheViewFramesTheModelTurnsAboutItAndADoubleClickFramesItForItsShapeNow() throws {
        let fixtures = try ModelFixtures(self)
        let model = try ModelLoader.load(contentsOf: fixtures.box("wide.obj", extent: [4, 1, 1]))
        let view = ModelSceneView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        view.show(model)
        XCTAssertTrue(view.allowsCameraControl)
        XCTAssertEqual(view.defaultCameraController.interactionMode, .orbitTurntable)
        XCTAssertTrue(view.isPlaying)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 400), styleMask: [.borderless], backing: .buffered, defer: true)
        window.contentView = view
        let framed = ModelFraming.camera(for: model.scene, aspect: 100.0 / 400.0).node.simdWorldPosition
        view.pointOfView?.simdPosition += SIMD3(5, 5, 5)
        let click = try XCTUnwrap(
            NSEvent.mouseEvent(
                with: .leftMouseDown, location: NSPoint(x: 150, y: 100), modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 2, pressure: 1))
        view.mouseDown(with: click)
        let back = try XCTUnwrap(view.pointOfView?.simdWorldPosition)
        XCTAssertEqual(simd_distance(back, framed), 0, accuracy: 0.001, "double-click frames it for the view's shape now")
        view.showsWireframe = true
        XCTAssertTrue(view.debugOptions.contains(.showWireframe))
        view.clear()
        XCTAssertNil(view.scene)
        XCTAssertNil(view.model)
    }
}
