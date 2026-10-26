//
//  GLTFAnimation.swift
//  GLTFReader
//
//  One animation: channels that drive node properties through samplers.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// One animation clip: channels that drive node properties, each through one of its samplers.
public struct GLTFAnimation: Decodable, Equatable, Sendable {
    /// The clip's name, when it has one.
    public let name: String?
    /// What the clip drives.
    public let channels: [GLTFAnimationChannel]
    /// The key times and values the channels read.
    public let samplers: [GLTFAnimationSampler]
}
