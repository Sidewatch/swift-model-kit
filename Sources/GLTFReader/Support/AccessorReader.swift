//
//  AccessorReader.swift
//  GLTFReader
//
//  An accessor's elements read from its buffer view's bytes, every range checked first.
//
//  Created by David Sherlock on 10/26/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// Reads accessors out of a file's buffers. Every index is looked up and every byte range is
/// checked, with overflow-safe arithmetic on the file's numbers, before a byte is read; a range that
/// does not fit is ``GLTFError/outOfRange(_:)``, never a trap. An accessor is capped at
/// ``maximumComponents``, so a small file cannot ask for a huge zero-filled one.
struct AccessorReader {
    let file: GLTFFile

    /// The most components (elements × their width) one accessor may have: 256 MB of floats.
    static let maximumComponents = 64_000_000

    /// The accessor's elements as floats, its components in a row; normalised integers mapped to
    /// 0…1 or -1…1, sparse substitutions applied.
    func floats(_ index: Int) throws -> [Float] {
        let accessor = try Self.element(file.document.accessors, index, "Accessor")
        let (type, component) = try Self.shape(accessor, index)
        let width = type.componentCount
        var values = [Float](repeating: 0, count: accessor.count * width)
        let normalized = accessor.normalized ?? false
        if let view = accessor.bufferView {
            try fill(
                &values, from: view, offset: accessor.byteOffset ?? 0, count: accessor.count, type: type, component: component,
                normalized: normalized, what: "Accessor \(index)")
        }
        if let sparse = accessor.sparse {
            let positions = try sparsePositions(sparse, of: accessor, index)
            var replacements = [Float](repeating: 0, count: sparse.count * width)
            try fill(
                &replacements, from: sparse.values.bufferView, offset: sparse.values.byteOffset ?? 0, count: sparse.count, type: type,
                component: component, normalized: normalized, what: "Accessor \(index)'s sparse values")
            for (k, position) in positions.enumerated() {
                for c in 0..<width { values[position * width + c] = replacements[k * width + c] }
            }
        }
        return values
    }

    /// A scalar accessor of unsigned integers (vertex or joint indices), as `UInt32`s: zeros where it
    /// has no buffer view, sparse substitutions applied, as for any accessor.
    func integers(_ index: Int) throws -> [UInt32] {
        let accessor = try Self.element(file.document.accessors, index, "Accessor")
        let (type, _) = try Self.shape(accessor, index)
        guard type == .scalar, Self.isUnsignedInteger(accessor.componentType) else {
            throw GLTFError.outOfRange("Accessor \(index) as indices")
        }
        var values =
            try accessor.bufferView.map {
                try integers(
                    from: $0, offset: accessor.byteOffset ?? 0, count: accessor.count, componentType: accessor.componentType,
                    what: "Accessor \(index)")
            } ?? [UInt32](repeating: 0, count: accessor.count)
        if let sparse = accessor.sparse {
            let positions = try sparsePositions(sparse, of: accessor, index)
            let replacements = try integers(
                from: sparse.values.bufferView, offset: sparse.values.byteOffset ?? 0, count: sparse.count,
                componentType: accessor.componentType, what: "Accessor \(index)'s sparse values")
            for (k, position) in positions.enumerated() { values[position] = replacements[k] }
        }
        return values
    }

    /// The elements a sparse substitution replaces, each checked against the accessor's count.
    private func sparsePositions(_ sparse: GLTFAccessorSparse, of accessor: GLTFAccessor, _ index: Int) throws -> [Int] {
        guard sparse.count >= 0, sparse.count <= accessor.count else { throw GLTFError.outOfRange("Accessor \(index)'s sparse count") }
        let positions = try integers(
            from: sparse.indices.bufferView, offset: sparse.indices.byteOffset ?? 0, count: sparse.count,
            componentType: sparse.indices.componentType, what: "Accessor \(index)'s sparse indices")
        return try positions.map {
            guard Int($0) < accessor.count else { throw GLTFError.outOfRange("Accessor \(index)'s sparse index \($0)") }
            return Int($0)
        }
    }

    // MARK: - Reading bytes

    /// Unsigned integers, one per element, from a buffer view.
    private func integers(from viewIndex: Int, offset: Int, count: Int, componentType: Int, what: String) throws -> [UInt32] {
        guard Self.isUnsignedInteger(componentType), let component = GLTFComponentType(rawValue: componentType) else {
            throw GLTFError.outOfRange("\(what)'s component type \(componentType)")
        }
        let (bytes, start, stride) = try range(viewIndex, offset: offset, count: count, elementSize: component.byteSize, what: what)
        var out = [UInt32](repeating: 0, count: count)
        bytes.withUnsafeBytes { raw in
            for i in 0..<count {
                let at = start + i * stride
                switch component {
                case .unsignedByte: out[i] = UInt32(raw[at])
                case .unsignedShort: out[i] = UInt32(UInt16(littleEndian: raw.loadUnaligned(fromByteOffset: at, as: UInt16.self)))
                default: out[i] = UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: at, as: UInt32.self))
                }
            }
        }
        return out
    }

    /// `count` elements of `type`, from a buffer view, into `values`, their components in a row.
    private func fill(
        _ values: inout [Float], from viewIndex: Int, offset: Int, count: Int, type: GLTFAccessorType, component: GLTFComponentType,
        normalized: Bool, what: String
    ) throws {
        let (size, offsets) = Self.layout(type, component)
        let width = offsets.count
        let (bytes, start, stride) = try range(viewIndex, offset: offset, count: count, elementSize: size, what: what)
        bytes.withUnsafeBytes { raw in
            for i in 0..<count {
                let base = start + i * stride
                for c in 0..<width {
                    values[i * width + c] = Self.component(raw, at: base + offsets[c], as: component, normalized: normalized)
                }
            }
        }
    }

    /// An element's size in bytes and where each of its components starts in it: in a row, except a
    /// 2×2 or 3×3 matrix of 1- or 2-byte components, each of whose columns starts on a 4-byte boundary
    /// (glTF 2.0, 3.6.2.4).
    static func layout(_ type: GLTFAccessorType, _ component: GLTFComponentType) -> (size: Int, offsets: [Int]) {
        let width = type.componentCount
        let bytes = component.byteSize
        guard let rows = type.matrixRows, (rows * bytes) % 4 != 0 else { return (width * bytes, (0..<width).map { $0 * bytes }) }
        let column = (rows * bytes + 3) / 4 * 4
        return (column * (width / rows), (0..<width).map { ($0 / rows) * column + ($0 % rows) * bytes })
    }

    /// The buffer behind a buffer view, where `count` elements of `elementSize` bytes start in it,
    /// and the stride between them — once all of it is known to lie inside the view and the buffer.
    private func range(_ viewIndex: Int, offset: Int, count: Int, elementSize: Int, what: String) throws -> (Data, Int, Int) {
        let view = try Self.element(file.document.bufferViews, viewIndex, "Buffer view")
        let bytes = try Self.element(file.buffers, view.buffer, "Buffer")
        let stride = view.byteStride ?? elementSize
        let viewStart = view.byteOffset ?? 0
        guard count >= 0, offset >= 0, viewStart >= 0, view.byteLength >= 0, stride >= elementSize,
            let viewEnd = Self.sum(viewStart, view.byteLength), viewEnd <= bytes.count,
            let start = Self.sum(viewStart, offset)
        else { throw GLTFError.outOfRange(what) }
        guard count > 0 else { return (bytes, start, stride) }
        guard let span = Self.product(stride, count - 1), let last = Self.sum(start, span), let end = Self.sum(last, elementSize),
            end <= viewEnd
        else { throw GLTFError.outOfRange(what) }
        return (bytes, start, stride)
    }

    /// One component at `at`, little-endian, as a float.
    private static func component(_ raw: UnsafeRawBufferPointer, at: Int, as type: GLTFComponentType, normalized: Bool) -> Float {
        switch type {
        case .float:
            return Float(bitPattern: UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: at, as: UInt32.self)))
        case .byte:
            let value = Float(Int8(bitPattern: raw[at]))
            return normalized ? max(value / 127, -1) : value
        case .unsignedByte:
            let value = Float(raw[at])
            return normalized ? value / 255 : value
        case .short:
            let value = Float(Int16(littleEndian: raw.loadUnaligned(fromByteOffset: at, as: Int16.self)))
            return normalized ? max(value / 32767, -1) : value
        case .unsignedShort:
            let value = Float(UInt16(littleEndian: raw.loadUnaligned(fromByteOffset: at, as: UInt16.self)))
            return normalized ? value / 65535 : value
        case .unsignedInt:
            return Float(UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: at, as: UInt32.self)))
        }
    }

    // MARK: - Checks

    /// An accessor's element type and component type, once both are known and its size is sane.
    private static func shape(_ accessor: GLTFAccessor, _ index: Int) throws -> (GLTFAccessorType, GLTFComponentType) {
        guard let type = GLTFAccessorType(rawValue: accessor.type), let component = GLTFComponentType(rawValue: accessor.componentType),
            accessor.count >= 0, accessor.count <= maximumComponents / type.componentCount
        else { throw GLTFError.outOfRange("Accessor \(index)") }
        return (type, component)
    }

    /// Whether `componentType` is one indices may use: an unsigned byte, short or int.
    private static func isUnsignedInteger(_ componentType: Int) -> Bool {
        guard let component = GLTFComponentType(rawValue: componentType) else { return false }
        return [.unsignedByte, .unsignedShort, .unsignedInt].contains(component)
    }

    /// `array[index]`, or ``GLTFError/outOfRange(_:)`` naming `what`.
    static func element<T>(_ array: [T]?, _ index: Int, _ what: String) throws -> T {
        guard let array, array.indices.contains(index) else { throw GLTFError.outOfRange("\(what) \(index)") }
        return array[index]
    }

    private static func sum(_ a: Int, _ b: Int) -> Int? {
        let (value, overflow) = a.addingReportingOverflow(b)
        return overflow ? nil : value
    }

    private static func product(_ a: Int, _ b: Int) -> Int? {
        let (value, overflow) = a.multipliedReportingOverflow(by: b)
        return overflow ? nil : value
    }
}
