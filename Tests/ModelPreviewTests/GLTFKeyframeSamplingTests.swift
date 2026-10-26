//
//  GLTFKeyframeSamplingTests.swift
//  ModelPreviewTests
//
//  Animation timing as glTF 2.0 defines it: clamped outside the keys, steps, cubic splines, and
//  rotations kept unit length on the short way round.
//
//  Created by David Sherlock on 10/27/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import GLTFReader
import XCTest
@testable import ModelPreview

final class GLTFKeyframeSamplingTests: XCTestCase {
    func testATrackHoldsItsFirstAndLastValuesOutsideItsKeys() throws {
        let frames = try XCTUnwrap(
            GLTFKeyframeSampling.keyframes(
                times: [0.5, 1], raw: [1, 1, 1, 2, 2, 2], width: 3, interpolation: .linear, rotation: false, duration: 2))
        XCTAssertEqual(frames.keyTimes, [0, 0.25, 0.5, 1], "from 0 and to the clip's end (glTF 3.11)")
        XCTAssertEqual(frames.values, [[1, 1, 1], [1, 1, 1], [2, 2, 2], [2, 2, 2]])
        XCTAssertFalse(frames.discrete)
    }

    func testAStepHoldsEachValueUntilTheNextKey() throws {
        let frames = try XCTUnwrap(
            GLTFKeyframeSampling.keyframes(
                times: [0, 1], raw: [1, 1, 1, 2, 2, 2], width: 3, interpolation: .step, rotation: false, duration: 2))
        XCTAssertTrue(frames.discrete)
        XCTAssertEqual(frames.values.count, 2)
        XCTAssertEqual(frames.keyTimes, [0, 0.5, 1], "one more key time than values: the last value holds to the end")
    }

    func testACubicSplineFollowsItsHermiteCurve() throws {
        // Key 0: value 0, out-tangent 2; key 1: value 1, in-tangent 0. Halfway the curve is
        // h10 · 1 · 2 + h01 · 1 = 0.125 · 2 + 0.5 = 0.75, where a straight line would be 0.5.
        let raw: [Float] = [0, 0, 0, 0, 0, 0, 2, 2, 2, 0, 0, 0, 1, 1, 1, 0, 0, 0]
        let frames = try XCTUnwrap(
            GLTFKeyframeSampling.keyframes(times: [0, 1], raw: raw, width: 3, interpolation: .cubicSpline, rotation: false, duration: 1))
        guard frames.values.count == 31 else { return XCTFail("30 samples a second, and the first key: \(frames.values.count) values") }
        XCTAssertEqual(frames.keyTimes[15], 0.5, accuracy: 0.0001)
        XCTAssertEqual(frames.values[15][0], 0.75, accuracy: 0.0001)
        XCTAssertEqual(frames.values.last, [1, 1, 1])
    }

    func testRotationsAreUnitLengthOnTheShortWayRound() throws {
        let frames = try XCTUnwrap(
            GLTFKeyframeSampling.keyframes(
                times: [0, 1], raw: [0, 0, 0, 1, 0, 0, 0, -2], width: 4, interpolation: .linear, rotation: true, duration: 1))
        XCTAssertEqual(frames.values[1], [0, 0, 0, 1], "-2w is the same rotation: made unit length and flipped to the first key's side")
    }

    func testNumbersThatAreNotFiniteDropTheTrack() {
        XCTAssertNil(
            GLTFKeyframeSampling.keyframes(
                times: [0, .nan], raw: [1, 1, 1, 2, 2, 2], width: 3, interpolation: .linear, rotation: false, duration: 1))
        XCTAssertNil(
            GLTFKeyframeSampling.keyframes(
                times: [0, 1], raw: [1, 1, 1, .infinity, 2, 2], width: 3, interpolation: .linear, rotation: false, duration: 1))
    }
}
