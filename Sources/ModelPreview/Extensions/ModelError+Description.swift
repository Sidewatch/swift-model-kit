//
//  ModelError+Description.swift
//  ModelPreview
//
//  A sentence for each reason a model could not be shown.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

extension ModelError: CustomStringConvertible {
    /// A sentence for the reason.
    public var description: String {
        switch self {
        case .unsupportedFormat(let ext): "“.\(ext)” is not a model format this package opens."
        case .unreadable(let reason): reason
        case .gltf(let error): error.description
        case .empty: "The file draws nothing."
        }
    }
}
