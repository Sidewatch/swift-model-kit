//
//  GLTFDocument.swift
//  GLTFReader
//
//  A glTF 2.0 document: the JSON that names every object by its index.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// A glTF 2.0 document as its JSON gives it: every object in an array, referred to by index. A
/// member the specification lets a file leave out is nil here; members a viewer never reads are
/// not decoded at all.
public struct GLTFDocument: Decodable, Equatable, Sendable {
    /// The glTF version and the tool that wrote the file.
    public let asset: GLTFAssetInfo
    /// The scene to show, by index; nil leaves the choice to the viewer.
    public let scene: Int?
    /// The scenes.
    public let scenes: [GLTFScene]?
    /// Every node of every scene.
    public let nodes: [GLTFNode]?
    /// The meshes.
    public let meshes: [GLTFMesh]?
    /// The accessors.
    public let accessors: [GLTFAccessor]?
    /// The buffer views.
    public let bufferViews: [GLTFBufferView]?
    /// The buffers.
    public let buffers: [GLTFBuffer]?
    /// The materials.
    public let materials: [GLTFMaterial]?
    /// The textures.
    public let textures: [GLTFTexture]?
    /// The images.
    public let images: [GLTFImage]?
    /// The texture samplers.
    public let samplers: [GLTFSampler]?
    /// The animation clips.
    public let animations: [GLTFAnimation]?
    /// The skins.
    public let skins: [GLTFSkin]?
    /// The extensions the file uses somewhere.
    public let extensionsUsed: [String]?
    /// The extensions without which the file cannot be read correctly.
    public let extensionsRequired: [String]?
}
