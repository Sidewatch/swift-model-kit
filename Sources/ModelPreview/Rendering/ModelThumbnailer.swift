//
//  ModelThumbnailer.swift
//  ModelPreview
//
//  A model drawn off screen, framed and lit as the view shows it: a gallery tile, a Quick Look icon.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Metal
import SceneKit

/// Draws a model off screen, framed (``ModelFraming``) and lit (``StudioLighting``) as the view shows
/// it, at time zero. Blocking: call it off the main thread; one model is drawn by one call at a time.
public enum ModelThumbnailer {
    /// `model` drawn `size` pixels large over `background` (clear by default); nil when there is no
    /// Metal device.
    public static func image(of model: LoadedModel, size: CGSize, background: CGColor? = nil) -> CGImage? {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        let scene = model.scene
        StudioLighting.apply(to: scene)
        let (camera, _) = ModelFraming.camera(for: scene, aspect: size.width / max(size.height, 1))
        scene.rootNode.addChildNode(camera)
        defer { camera.removeFromParentNode() }
        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = camera
        renderer.autoenablesDefaultLighting = false
        let previousBackground = scene.background.contents
        scene.background.contents = background ?? CGColor(gray: 0, alpha: 0)
        defer { scene.background.contents = previousBackground }
        let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
