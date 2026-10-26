//
//  StudioLighting.swift
//  ModelPreview
//
//  The light a model is shown in when its file brings none: a soft studio sky and a key light.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import SceneKit

/// The light a model is shown in: a soft studio sky as the lighting environment, which metals
/// reflect and every material is lit by, and, when the file brings no light of its own, a key light
/// from above, front and right that casts the shading a shape is read by.
enum StudioLighting {
    /// Lights `scene` for showing, once (a second call changes nothing).
    static func apply(to scene: SCNScene) {
        guard scene.rootNode.childNode(withName: keyLightName, recursively: false) == nil else { return }
        if scene.lightingEnvironment.contents == nil {
            scene.lightingEnvironment.contents = sky
            scene.lightingEnvironment.intensity = 1.2
        }
        let hasLights = scene.rootNode.descendants.contains { $0.light != nil }
        guard !hasLights else { return }
        let key = SCNNode()
        key.name = keyLightName
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 900
        key.simdEulerAngles = SIMD3(-0.9, 0.6, 0)
        scene.rootNode.addChildNode(key)
    }

    private static let keyLightName = "Studio key light"

    /// A 256 × 128 equirectangular sky: light grey-blue overhead, a bright horizon, a darker floor.
    private static let sky: CGImage? = {
        let (width, height) = (256, 128)
        guard
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        let colors = [
            CGColor(red: 0.80, green: 0.84, blue: 0.90, alpha: 1), CGColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1),
            CGColor(red: 0.42, green: 0.42, blue: 0.44, alpha: 1), CGColor(red: 0.22, green: 0.22, blue: 0.23, alpha: 1),
        ]
        guard
            let gradient = CGGradient(
                colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: [0, 0.48, 0.52, 1])
        else { return nil }
        // The context's origin is the bottom: draw from the top (overhead) down to the floor.
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height), end: CGPoint(x: 0, y: 0), options: [])
        return context.makeImage()
    }()
}
