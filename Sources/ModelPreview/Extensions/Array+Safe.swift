//
//  Array+Safe.swift
//  ModelPreview
//
//  An element by index, or nil when the index is out of range.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

extension Array {
    /// The element at `index`, or nil when there is none: for indices a file gives.
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
