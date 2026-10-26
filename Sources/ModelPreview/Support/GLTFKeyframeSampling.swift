//
//  GLTFKeyframeSampling.swift
//  ModelPreview
//
//  A glTF animation sampler's keys as Core Animation key frames, timed as the spec says.
//
//  Created by David Sherlock on 10/27/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation
import GLTFReader
import simd

/// Turns a glTF animation sampler's input times and output values into ``GLTFKeyframes`` over a clip:
/// the output clamped before the first key and after the last (glTF 3.11), a step holding each value
/// until the next key, a cubic spline sampled from its Hermite curve (Appendix C), and rotations kept
/// unit length and on the short way round.
enum GLTFKeyframeSampling {
    /// Samples per second a cubic spline is drawn with.
    static let splineRate: Float = 30
    /// The most samples one spline track is drawn with, however long its clip.
    static let maximumSplineSamples = 100_000

    /// The sampler's key frames over a clip of `duration` seconds; nil when the keys and the values do
    /// not match, any number is not finite, or the clip has no length.
    static func keyframes(
        times: [Float], raw: [Float], width: Int, interpolation: GLTFInterpolation, rotation: Bool, duration: Float
    ) -> GLTFKeyframes? {
        guard duration > 0, duration.isFinite, !times.isEmpty, times.allSatisfy(\.isFinite), raw.allSatisfy(\.isFinite),
            var values = Self.values(raw, width: width, keys: times.count, cubic: interpolation == .cubicSpline)
        else { return nil }
        var keyTimes = times
        if interpolation == .cubicSpline { (keyTimes, values) = Self.sampleHermite(times: times, raw: raw, width: width) }
        if rotation { values = Self.shortestPath(values.map(Self.unitQuaternion)) }
        if keyTimes[0] > 0 {
            keyTimes.insert(0, at: 0)
            values.insert(values[0], at: 0)
        }
        if interpolation == .step {
            return GLTFKeyframes(keyTimes: keyTimes.map { Double($0 / duration) } + [1], values: values, discrete: true)
        }
        if keyTimes[keyTimes.count - 1] < duration {
            keyTimes.append(duration)
            values.append(values[values.count - 1])
        }
        return GLTFKeyframes(keyTimes: keyTimes.map { Double($0 / duration) }, values: values, discrete: false)
    }

    /// One value of `width` floats per key; a cubic spline stores an in-tangent, the value and an
    /// out-tangent per key, and only the value is taken. Nil when the counts do not match.
    static func values(_ raw: [Float], width: Int, keys: Int, cubic: Bool) -> [[Float]]? {
        let stride = cubic ? width * 3 : width
        guard keys > 0, raw.count == keys * stride else { return nil }
        let skip = cubic ? width : 0
        return (0..<keys).map { Array(raw[$0 * stride + skip..<$0 * stride + skip + width]) }
    }

    /// A cubic spline drawn as straight segments at ``splineRate`` (fewer when the track is long): between
    /// two keys, the Hermite curve of their values with the first one's out-tangent and the second one's
    /// in-tangent, each scaled by the time between them.
    static func sampleHermite(times: [Float], raw: [Float], width: Int) -> (times: [Float], values: [[Float]]) {
        func part(_ key: Int, _ which: Int) -> [Float] { Array(raw[(key * 3 + which) * width..<(key * 3 + which + 1) * width]) }
        let span = max(times[times.count - 1] - times[0], 0)
        let rate = span * splineRate > Float(maximumSplineSamples) ? Float(maximumSplineSamples) / span : splineRate
        var outTimes = [times[0]]
        var outValues = [part(0, 1)]
        for key in 0..<times.count - 1 {
            let gap = times[key + 1] - times[key]
            let steps = gap > 0 ? max(1, Int((gap * rate).rounded(.up))) : 1
            let (v0, out0, v1, in1) = (part(key, 1), part(key, 2), part(key + 1, 1), part(key + 1, 0))
            for step in 1...steps {
                let s = Float(step) / Float(steps)
                let (s2, s3) = (s * s, s * s * s)
                let (h00, h10, h01, h11) = (2 * s3 - 3 * s2 + 1, s3 - 2 * s2 + s, -2 * s3 + 3 * s2, s3 - s2)
                outTimes.append(times[key] + s * max(gap, 0))
                outValues.append((0..<width).map { h00 * v0[$0] + h10 * gap * out0[$0] + h01 * v1[$0] + h11 * gap * in1[$0] })
            }
        }
        return (outTimes, outValues)
    }

    /// A quaternion `x y z w` made unit length (glTF Appendix C normalises an interpolated rotation);
    /// a zero one is the identity.
    static func unitQuaternion(_ q: [Float]) -> [Float] {
        let v = SIMD4(q[0], q[1], q[2], q[3])
        let length = simd_length(v)
        return length > 0 ? [v.x / length, v.y / length, v.z / length, v.w / length] : [0, 0, 0, 1]
    }

    /// Rotations each on the same side as the one before (`q` and `-q` are one rotation), so blending
    /// between keys takes the short way round.
    static func shortestPath(_ rotations: [[Float]]) -> [[Float]] {
        var out = rotations
        for i in out.indices.dropFirst() {
            let dot = zip(out[i], out[i - 1]).reduce(Float(0)) { $0 + $1.0 * $1.1 }
            if dot < 0 { out[i] = out[i].map { -$0 } }
        }
        return out
    }
}
