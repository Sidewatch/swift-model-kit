//
//  LoadedModel.swift
//  ModelPreview
//
//  A model read and ready to show: its scene and its facts.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation
import SceneKit

/// A model read and ready to show: its scene, Y up, and its measured facts.
///
/// `@unchecked Sendable`: it is built whole on the thread that loads it and never mutated after,
/// so it can be handed to the main thread; SceneKit guards its own graph while it is drawn.
public final class LoadedModel: @unchecked Sendable {
    /// The file it was read from.
    public let url: URL
    /// Its scene, Y up.
    public let scene: SCNScene
    /// What it holds, measured.
    public let facts: ModelFacts

    /// A model and its facts.
    public init(url: URL, scene: SCNScene, facts: ModelFacts) {
        self.url = url
        self.scene = scene
        self.facts = facts
    }
}
