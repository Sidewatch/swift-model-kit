//
//  ModelFraming.swift
//  ModelPreview
//
//  A camera that sees a whole model: in front, a little above and to the right, with room around it.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import SceneKit

/// Where a camera stands to see a whole model, the same for the view and for a thumbnail: in front
/// (+Z), a little to the right and above, far enough that the model's bounding sphere fits the
/// narrower of the two fields of view with a margin, looking at the sphere's centre.
public enum ModelFraming {
    /// The vertical field of view, in degrees.
    static let fieldOfView: CGFloat = 35
    /// The direction from the model to the camera: front, right, above.
    static let direction = SIMD3<Float>(0.55, 0.35, 1.0)

    /// A camera node framing `scene` for a view `aspect` wide per unit of height, and the point it
    /// looks at (what the view orbits around).
    public static func camera(for scene: SCNScene, aspect: CGFloat) -> (node: SCNNode, target: SIMD3<Float>) {
        let (centre, sphereRadius) = scene.rootNode.boundingSphere
        let target = SIMD3<Float>(Float(centre.x), Float(centre.y), Float(centre.z))
        let radius = max(Float(sphereRadius), 0.0001)
        let vertical = Float(fieldOfView) * .pi / 180
        let horizontal = 2 * atan(tan(vertical / 2) * Float(max(aspect, 0.01)))
        let distance = radius / sin(min(vertical, horizontal) / 2) * 1.08
        let camera = SCNCamera()
        camera.fieldOfView = fieldOfView
        camera.zNear = Double(max(distance - radius * 2, distance * 0.001))
        camera.zFar = Double(distance + radius * 4)
        let node = SCNNode()
        node.name = "Framing camera"
        node.camera = camera
        node.simdPosition = target + simd_normalize(direction) * distance
        node.simdLook(at: target)
        return (node, target)
    }
}
