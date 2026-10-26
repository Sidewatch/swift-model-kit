//
//  GLTFComponentType+Size.swift
//  GLTFReader
//
//  The byte size of each component type.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

extension GLTFComponentType {
    /// Bytes per component.
    public var byteSize: Int {
        switch self {
        case .byte, .unsignedByte: 1
        case .short, .unsignedShort: 2
        case .unsignedInt, .float: 4
        }
    }
}
