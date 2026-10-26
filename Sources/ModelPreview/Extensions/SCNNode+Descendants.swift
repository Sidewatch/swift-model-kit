//
//  SCNNode+Descendants.swift
//  ModelPreview
//
//  Every node below a node, in one list.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import SceneKit

extension SCNNode {
    /// This node and every node below it, parents before their children.
    var descendants: [SCNNode] {
        var nodes: [SCNNode] = []
        enumerateHierarchy { node, _ in nodes.append(node) }
        return nodes
    }
}
