//
//  ModelLoader.swift
//  ModelPreview
//
//  Reading a model file into a scene, Y up, with its facts.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation
import GLTFReader
import SceneKit

/// Reads model files. glTF and GLB are built by ``GLTFSceneBuilder`` from `GLTFReader`; every other
/// format is read by SceneKit, asked to turn a Z-up file Y up (USD and Collada say which axis is up).
/// An STL says nothing and is Z up by convention, so it is turned here.
public enum ModelLoader {
    /// Reads the model at `url`. Blocking: call it off the main thread. Throws when the format is
    /// not one this package opens, the file cannot be read, or it draws nothing.
    public static func load(contentsOf url: URL) throws -> LoadedModel {
        guard let format = ModelFormat(url: url) else { throw ModelError.unsupportedFormat(url.pathExtension) }
        let scene: SCNScene
        var animations: Int
        var vertices: Int?
        if format.isGLTF {
            do {
                let built = try GLTFSceneBuilder.scene(from: GLTFFile.read(contentsOf: url))
                (scene, animations, vertices) = (built.scene, built.animations, built.vertices)
            } catch let error as GLTFError {
                throw ModelError.gltf(error)
            }
        } else {
            do {
                scene = try SCNScene(url: url, options: [.convertToYUp: true])
            } catch {
                throw ModelError.unreadable((error as NSError).localizedFailureReason ?? error.localizedDescription)
            }
            animations = Set(scene.rootNode.descendants.flatMap(\.animationKeys)).count
        }
        if format.isZUpByConvention { standUp(scene) }
        let facts = ModelFacts.measure(scene, format: format, animations: animations, stoodUp: format.isZUpByConvention, vertices: vertices)
        guard facts.meshes > 0 else { throw ModelError.empty }
        return LoadedModel(url: url, scene: scene, facts: facts)
    }

    /// Turns a Z-up scene Y up: its root's children go under one node turned a quarter about X, so
    /// +Z becomes +Y and the front (-Y in CAD) faces +Z, the viewer.
    static func standUp(_ scene: SCNScene) {
        let upright = SCNNode()
        upright.name = "Upright"
        upright.eulerAngles.x = -.pi / 2
        for child in scene.rootNode.childNodes {
            child.removeFromParentNode()
            upright.addChildNode(child)
        }
        scene.rootNode.addChildNode(upright)
    }
}
