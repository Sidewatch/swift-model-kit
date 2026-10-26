//
//  GLTFFile+Accessors.swift
//  GLTFReader
//
//  An accessor's values, an image's bytes and the scene's nodes, read from a file.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

extension GLTFFile {
    /// Accessor `index`'s elements as floats, the components of each in a row: a `VEC3` of 10
    /// elements is 30 floats. Normalised integers read as 0…1 or -1…1; sparse substitutions are
    /// applied. Throws when the accessor or any byte it names is out of range.
    public func floats(accessor index: Int) throws -> [Float] {
        try AccessorReader(file: self).floats(index)
    }

    /// Accessor `index`'s scalars as unsigned integers: vertex indices, joint indices.
    public func integers(accessor index: Int) throws -> [UInt32] {
        try AccessorReader(file: self).integers(index)
    }

    /// The encoded bytes (PNG, JPEG…) of image `index`, from its buffer view or its URI.
    public func imageData(_ index: Int) throws -> Data {
        let image = try AccessorReader.element(document.images, index, "Image")
        if let viewIndex = image.bufferView {
            let view = try AccessorReader.element(document.bufferViews, viewIndex, "Buffer view")
            let bytes = try AccessorReader.element(buffers, view.buffer, "Buffer")
            let start = view.byteOffset ?? 0
            guard start >= 0, view.byteLength >= 0, start <= bytes.count, view.byteLength <= bytes.count - start else {
                throw GLTFError.outOfRange("Image \(index)'s buffer view")
            }
            return bytes.subdata(in: bytes.startIndex + start..<bytes.startIndex + start + view.byteLength)
        }
        guard let uri = image.uri, let data = ResourceURI.data(uri, folder: folder) else {
            throw GLTFError.unreadableImage(index: index, uri: image.uri)
        }
        return data
    }

    /// The nodes at the root of the scene to show: the document's `scene`, else its first, else
    /// every node that is no other node's child.
    public var rootNodes: [Int] {
        let scenes = document.scenes ?? []
        if let chosen = document.scene, scenes.indices.contains(chosen) { return scenes[chosen].nodes ?? [] }
        if let first = scenes.first { return first.nodes ?? [] }
        let nodes = document.nodes ?? []
        let children = Set(nodes.flatMap { $0.children ?? [] })
        return nodes.indices.filter { !children.contains($0) }
    }
}
