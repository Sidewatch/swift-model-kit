//
//  AccessorReaderTests.swift
//  GLTFReaderTests
//
//  Accessor layouts the spec spells out: matrix columns on 4-byte boundaries, and sparse
//  substitutions in index accessors as in any other.
//
//  Created by David Sherlock on 10/27/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import XCTest
@testable import GLTFReader

final class AccessorReaderTests: XCTestCase {
    func testMatrixColumnsOfSmallComponentsStartOnFourByteBoundaries() throws {
        var b = GLTFBuilder()
        // glTF 3.6.2.4: a MAT3 of bytes is 12 bytes, each column padded to 4; a MAT2 of bytes is 8.
        let mat3 = b.accessor(view: b.view(Data([1, 2, 3, 0, 4, 5, 6, 0, 7, 8, 9, 0])), type: "MAT3", componentType: 5121, count: 1)
        let mat2 = b.accessor(view: b.view(Data([1, 2, 0, 0, 3, 4, 0, 0])), type: "MAT2", componentType: 5121, count: 1)
        let shorts = GLTFBuilder.uint16s([1, 2, 3, 0, 4, 5, 6, 0, 7, 8, 9, 0])
        let mat3Shorts = b.accessor(view: b.view(shorts), type: "MAT3", componentType: 5123, count: 1)
        let file = try GLTFFile.read(b.gltfWithDataURI(), folder: nil)
        XCTAssertEqual(try file.floats(accessor: mat3), [1, 2, 3, 4, 5, 6, 7, 8, 9])
        XCTAssertEqual(try file.floats(accessor: mat2), [1, 2, 3, 4])
        XCTAssertEqual(try file.floats(accessor: mat3Shorts), [1, 2, 3, 4, 5, 6, 7, 8, 9], "6-byte columns padded to 8")
    }

    func testAnIndexAccessorTakesItsSparseSubstitutions() throws {
        var b = GLTFBuilder()
        let positions = b.view(GLTFBuilder.uint16s([2]))
        let values = b.view(GLTFBuilder.uint16s([9]))
        let sparse: [String: Any] = [
            "count": 1, "indices": ["bufferView": positions, "componentType": 5123], "values": ["bufferView": values],
        ]
        let overView = b.accessor(
            view: b.view(GLTFBuilder.uint16s([0, 1, 2, 3])), type: "SCALAR", componentType: 5123, count: 4, extra: ["sparse": sparse])
        let overZeros = b.accessor(view: nil, type: "SCALAR", componentType: 5123, count: 4, extra: ["sparse": sparse])
        let file = try GLTFFile.read(b.gltfWithDataURI(), folder: nil)
        XCTAssertEqual(try file.integers(accessor: overView), [0, 1, 9, 3])
        XCTAssertEqual(try file.integers(accessor: overZeros), [0, 0, 9, 0], "no buffer view: zeros, then the substitutions")
    }

    func testIndicesMustBeUnsignedIntegers() throws {
        var b = GLTFBuilder()
        let floats = b.accessor(view: b.view(GLTFBuilder.floats([0, 1, 2])), type: "SCALAR", componentType: 5126, count: 3)
        let floatZeros = b.accessor(view: nil, type: "SCALAR", componentType: 5126, count: 3)
        let file = try GLTFFile.read(b.gltfWithDataURI(), folder: nil)
        XCTAssertThrowsError(try file.integers(accessor: floats))
        XCTAssertThrowsError(try file.integers(accessor: floatZeros), "refused before any bytes, with no view to read")
    }
}
