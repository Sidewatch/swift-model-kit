//
//  ModelSceneView.swift
//  ModelPreview
//
//  An interactive 3D view of one model: turn it, zoom, pan, frame it again; its animation plays.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import AppKit
import SceneKit

/// One model, shown to be looked at: drag to turn it about its centre (a turntable, so it never
/// rolls), scroll or pinch to zoom, ⌥-drag or a two-finger drag to pan, double-click to frame it as
/// it opened. It is framed (``ModelFraming``) and lit (``StudioLighting``) as its thumbnail is, and
/// its animation plays. The host sets ``backgroundColor`` to its own page colour.
public final class ModelSceneView: SCNView {
    /// The model on show; nil before ``show(_:)`` and after ``clear()``.
    public private(set) var model: LoadedModel?
    /// The point the turntable turns about: the model's centre.
    private var target = SIMD3<Float>.zero
    /// Framing waits for a size: a view shown before it is laid out frames on its first layout.
    private var needsFraming = false

    /// Draws every triangle's edges over the shaded model.
    public var showsWireframe = false {
        didSet { debugOptions = showsWireframe ? debugOptions.union(.showWireframe) : debugOptions.subtracting(.showWireframe) }
    }

    public override init(frame: NSRect, options: [String: Any]? = nil) {
        super.init(frame: frame, options: options)
        configure()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        allowsCameraControl = true
        antialiasingMode = .multisampling4X
        autoenablesDefaultLighting = false
        defaultCameraController.interactionMode = .orbitTurntable
        defaultCameraController.inertiaEnabled = true
        setAccessibilityRole(.image)
    }

    /// Shows `model`, framed, its animation playing.
    public func show(_ model: LoadedModel) {
        self.model = model
        StudioLighting.apply(to: model.scene)
        scene = model.scene
        isPlaying = true
        loops = true
        needsFraming = true
        if bounds.width > 0, bounds.height > 0 { frameModel(animated: false) }
    }

    /// Puts the camera back where the model opened: framed in front, a little above and to the right.
    public func frameModel(animated: Bool) {
        guard let scene else { return }
        needsFraming = false
        let (camera, target) = ModelFraming.camera(for: scene, aspect: bounds.width / max(bounds.height, 1))
        self.target = target
        pointOfView?.removeFromParentNode()
        SCNTransaction.begin()
        SCNTransaction.animationDuration = animated ? 0.35 : 0
        scene.rootNode.addChildNode(camera)
        pointOfView = camera
        defaultCameraController.target = SCNVector3(target.x, target.y, target.z)
        SCNTransaction.commit()
    }

    /// Stops drawing and lets the model go.
    public func clear() {
        isPlaying = false
        pointOfView?.removeFromParentNode()
        scene = nil
        model = nil
    }

    public override func layout() {
        super.layout()
        if needsFraming, bounds.width > 0, bounds.height > 0 { frameModel(animated: false) }
    }

    public override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            frameModel(animated: true)
            return
        }
        super.mouseDown(with: event)
    }
}
