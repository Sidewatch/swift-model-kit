//
//  GLTFError+Description.swift
//  GLTFReader
//
//  A sentence for each reason a glTF file could not be read.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

extension GLTFError: CustomStringConvertible {
    /// A sentence for the reason, naming what was wrong.
    public var description: String {
        switch self {
        case .notGLTF: "Not a glTF document."
        case .unsupportedVersion(let version): "glTF \(version) is not supported (2.0 is)."
        case .truncated: "The GLB container is cut short."
        case .requiredExtensions(let names): "It needs \(names.joined(separator: ", ")), which this reader does not decode."
        case .unreadableBuffer(let index, let uri):
            uri.map { "Buffer \(index) (\($0)) could not be read." } ?? "Buffer \(index) is missing from the GLB container."
        case .unreadableImage(let index, let uri):
            uri.map { "Image \(index) (\($0)) could not be read." } ?? "Image \(index) could not be read."
        case .outOfRange(let what): "\(what) is out of range."
        case .tooLarge(let what): "\(what) is too large to show."
        case .malformed(let sentence): sentence
        }
    }
}
