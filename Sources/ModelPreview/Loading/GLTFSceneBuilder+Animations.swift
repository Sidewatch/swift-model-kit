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
    /// Plays the file's first animation clip on the built nodes, looping over the clip's length:
    /// each channel's translation, rotation or scale keys as a key-frame animation (a cubic spline's
    /// values without its tangents, a step as discrete). Morph-weight channels, and channels whose
    /// keys and values do not match, are left out.
    func animate() throws {
        guard let clip = file.document.animations?.first else { return }
        var tracks: [(node: SCNNode, keyPath: String, times: [Float], values: [NSValue], discrete: Bool)] = []
        for channel in clip.channels {
            guard let target = channel.target.node, let node = nodes[target], let path = GLTFAnimationPath(rawValue: channel.target.path),
                path != .weights, let sampler = clip.samplers[safe: channel.sampler]
            else { continue }
            let times = try file.floats(accessor: sampler.input)
            let raw = try file.floats(accessor: sampler.output)
            let interpolation = GLTFInterpolation(rawValue: sampler.interpolation ?? "LINEAR") ?? .linear
            let width = path == .rotation ? 4 : 3
            let values = Self.keyValues(raw, width: width, keys: times.count, cubic: interpolation == .cubicSpline)
            guard !times.isEmpty, values.count == times.count else { continue }
            tracks.append((node, Self.keyPath(path), times, values.map { Self.value($0, path: path) }, interpolation == .step))
        }
        let duration = tracks.compactMap { $0.times.last }.max() ?? 0
        guard duration > 0 else { return }
        for (index, track) in tracks.enumerated() {
            let animation = CAKeyframeAnimation(keyPath: track.keyPath)
            animation.values = track.values
            animation.keyTimes = track.times.map { NSNumber(value: Double($0 / duration)) }
            animation.calculationMode = track.discrete ? .discrete : .linear
            animation.duration = CFTimeInterval(duration)
            animation.repeatCount = .infinity
            track.node.addAnimation(SCNAnimation(caAnimation: animation), forKey: "gltf-\(index)")
        }
    }

    /// One value of `width` floats per key; a cubic spline stores an in-tangent, the value and an
    /// out-tangent per key, and only the value is kept.
    static func keyValues(_ raw: [Float], width: Int, keys: Int, cubic: Bool) -> [[Float]] {
        let stride = cubic ? width * 3 : width
        guard raw.count == keys * stride else { return [] }
        let skip = cubic ? width : 0
        return (0..<keys).map { Array(raw[$0 * stride + skip..<$0 * stride + skip + width]) }
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
