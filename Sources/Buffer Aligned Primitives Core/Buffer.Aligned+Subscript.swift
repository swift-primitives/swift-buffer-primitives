// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// MARK: - Range Subscripts (Read-Only)

extension Buffer.Aligned where Element == UInt8 {
    /// Accesses a contiguous subrange of bytes as a `Span`.
    ///
    /// This subscript provides zero-copy access to a subrange of the buffer.
    /// The returned span is lifetime-bound to `self` and must not escape.
    ///
    /// - Parameter range: The range of bytes to access.
    /// - Returns: A span viewing the specified range.
    ///
    /// - Precondition: `range.lowerBound >= 0`
    /// - Precondition: `range.upperBound <= count`
    @inlinable
    public subscript(range: Swift.Range<Int>) -> Span<UInt8> {
        @_lifetime(borrow self)
        borrowing get {
            bytes.extracting(range)
        }
    }

    /// Accesses bytes from a given offset to the end as a `Span`.
    ///
    /// - Parameter range: A partial range from a lower bound.
    /// - Returns: A span viewing from the offset to the end.
    @inlinable
    public subscript(range: PartialRangeFrom<Int>) -> Span<UInt8> {
        @_lifetime(borrow self)
        borrowing get {
            bytes.extracting(range.lowerBound..<Int(bitPattern: count.cardinal))
        }
    }

    /// Accesses bytes from the beginning up to a given offset as a `Span`.
    ///
    /// - Parameter range: A partial range up to an upper bound.
    /// - Returns: A span viewing from the beginning to the offset.
    @inlinable
    public subscript(range: PartialRangeUpTo<Int>) -> Span<UInt8> {
        @_lifetime(borrow self)
        borrowing get {
            bytes.extracting(0..<range.upperBound)
        }
    }

    /// Accesses bytes from the beginning through a given offset as a `Span`.
    ///
    /// - Parameter range: A partial range through an upper bound (inclusive).
    /// - Returns: A span viewing from the beginning through the offset.
    @inlinable
    public subscript(range: PartialRangeThrough<Int>) -> Span<UInt8> {
        @_lifetime(borrow self)
        borrowing get {
            bytes.extracting(0...range.upperBound)
        }
    }
}

// MARK: - Mutable Range Access
//
// Note: Mutable range subscripts returning MutableSpan are not currently possible
// due to Swift lifetime tracking limitations with MutableSpan._mutatingExtracting.
// Use the closure-based API instead:
//
//     buffer.withMutableBytes(in: 0..<16) { subBuffer in
//         // work with subBuffer
//     }
//
// This API is provided by Memory.Contiguous+RangeAccess.swift.
