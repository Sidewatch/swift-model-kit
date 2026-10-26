//
//  GLTFSceneBuilder+Animations.swift
//  ModelPreview
//
//  The first glTF animation clip as SceneKit key-frame animations, looping.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation
import GLTFReader
import QuartzCore
import SceneKit

extension GLTFSceneBuilder {
    /// Plays the file's first animation clip on the built nodes, looping over the clip's length: each
    /// channel's translation, rotation or scale as a key-frame animation timed by
    /// ``GLTFKeyframeSampling``. A clip whose keys all sit at time 0 is a pose, applied and held.
    /// Morph-weight channels, and channels whose keys and values do not match, are left out.
    func animate() throws {
        guard let clip = file.document.animations?.first else { return }
        var tracks: [(node: SCNNode, path: GLTFAnimationPath, times: [Float], raw: [Float], interpolation: GLTFInterpolation)] = []
        for channel in clip.channels {
            guard let target = channel.target.node, let node = nodes[target], let path = GLTFAnimationPath(rawValue: channel.target.path),
                path != .weights, let sampler = clip.samplers[safe: channel.sampler]
            else { continue }
            let times = try floats(sampler.input)
            guard !times.isEmpty else { continue }
            let interpolation = GLTFInterpolation(rawValue: sampler.interpolation ?? "LINEAR") ?? .linear
            tracks.append((node, path, times, try floats(sampler.output), interpolation))
        }
        let duration = tracks.compactMap { $0.times.last }.max() ?? 0
        for (index, track) in tracks.enumerated() {
            let width = track.path == .rotation ? 4 : 3
            guard duration > 0 else {
                let first = GLTFKeyframeSampling.values(
                    track.raw, width: width, keys: track.times.count, cubic: track.interpolation == .cubicSpline)?.first
                if let first, first.allSatisfy(\.isFinite) { Self.pose(track.node, track.path, first) }
                continue
            }
            guard
                let frames = GLTFKeyframeSampling.keyframes(
                    times: track.times, raw: track.raw, width: width, interpolation: track.interpolation, rotation: track.path == .rotation,
                    duration: duration)
            else { continue }
            let animation = CAKeyframeAnimation(keyPath: Self.keyPath(track.path))
            animation.values = frames.values.map { Self.value($0, path: track.path) }
            animation.keyTimes = frames.keyTimes.map { NSNumber(value: $0) }
            animation.calculationMode = frames.discrete ? .discrete : .linear
            animation.duration = CFTimeInterval(duration)
            animation.repeatCount = .infinity
            track.node.addAnimation(SCNAnimation(caAnimation: animation), forKey: "gltf-\(index)")
        }
    }

    /// Sets a pose's value on `node` directly: its translation, rotation (made unit length) or scale.
    static func pose(_ node: SCNNode, _ path: GLTFAnimationPath, _ v: [Float]) {
        switch path {
        case .translation: node.simdPosition = SIMD3(v[0], v[1], v[2])
        case .rotation:
            let q = GLTFKeyframeSampling.unitQuaternion(v)
            node.simdOrientation = simd_quatf(ix: q[0], iy: q[1], iz: q[2], r: q[3])
        case .scale: node.simdScale = SIMD3(v[0], v[1], v[2])
        case .weights: break
        }
    }

    private static func keyPath(_ path: GLTFAnimationPath) -> String {
        switch path {
        case .translation: "position"
        case .rotation: "orientation"
        case .scale, .weights: "scale"
        }
    }

    private static func value(_ v: [Float], path: GLTFAnimationPath) -> NSValue {
        path == .rotation
            ? NSValue(scnVector4: SCNVector4(v[0], v[1], v[2], v[3]))
            : NSValue(scnVector3: SCNVector3(v[0], v[1], v[2]))
    }
}
