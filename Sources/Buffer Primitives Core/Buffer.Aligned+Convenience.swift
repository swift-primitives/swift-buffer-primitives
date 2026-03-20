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

// MARK: - Single Byte Access

extension Buffer.Aligned where Element == UInt8 {
    /// Accesses the byte at the given index.
    ///
    /// - Parameter index: The byte index to access.
    /// - Returns: The byte value at that index.
    ///
    /// - Precondition: `index >= 0 && index < count`
    ///
    /// - Note: For bulk access, prefer `bytes`, `mutableBytes`, or `withUnsafeBytes`.
    ///   Single-byte subscripting is intended for debugging and infrequent access.
    @inlinable
    public subscript(index: Int) -> UInt8 {
        get {
            precondition(index >= 0 && index < Int(bitPattern: count.cardinal), "index out of bounds")
            return unsafe bytePointer[index]
        }
        set {
            precondition(index >= 0 && index < Int(bitPattern: count.cardinal), "index out of bounds")
            unsafe bytePointer[index] = newValue
        }
    }
}

// MARK: - Copy Convenience

extension Buffer.Aligned where Element == UInt8 {
    /// Copies bytes from a source span into this buffer at the given offset.
    ///
    /// - Parameters:
    ///   - source: The source span to copy from.
    ///   - offset: The byte offset in this buffer where copying begins. Defaults to 0.
    ///
    /// - Precondition: `offset >= 0`
    /// - Precondition: `offset + source.count <= self.count`
    @inlinable
    public mutating func copy(
        from source: Span<UInt8>,
        at offset: Int = 0
    ) {
        precondition(offset >= 0 && offset + source.count <= Int(bitPattern: count.cardinal))
        unsafe withUnsafeMutableBufferPointer { dest in
            source.withUnsafeBufferPointer { src in
                unsafe dest.baseAddress!.advanced(by: offset)
                    .update(from: src.baseAddress!, count: src.count)
            }
        }
    }

    /// Copies bytes from a raw buffer pointer into this buffer at the given offset.
    ///
    /// - Parameters:
    ///   - source: The raw buffer pointer to copy from.
    ///   - offset: The byte offset in this buffer where copying begins. Defaults to 0.
    ///
    /// - Precondition: `offset >= 0`
    /// - Precondition: `offset + source.count <= self.count`
    @inlinable
    public mutating func copy(
        from source: UnsafeRawBufferPointer,
        at offset: Int = 0
    ) {
        precondition(offset >= 0 && offset + source.count <= Int(bitPattern: count.cardinal))
        unsafe withUnsafeMutableBytes { dest in
            unsafe dest.baseAddress!.advanced(by: offset)
                .copyMemory(from: source.baseAddress!, byteCount: source.count)
        }
    }
}

// MARK: - Zero Convenience

extension Buffer.Aligned where Element == UInt8 {
    /// Zeroes all bytes in this buffer.
    @inlinable
    public mutating func zero() {
        unsafe withUnsafeMutableBytes { buffer in
            unsafe buffer.baseAddress?.initializeMemory(as: UInt8.self, repeating: 0, count: buffer.count)
        }
    }

    /// Zeroes bytes in the specified range.
    ///
    /// - Parameter range: The range of bytes to zero.
    ///
    /// - Precondition: `range.lowerBound >= 0`
    /// - Precondition: `range.upperBound <= count`
    @inlinable
    public mutating func zero(range: Swift.Range<Int>) {
        precondition(range.lowerBound >= 0 && range.upperBound <= Int(bitPattern: count.cardinal))
        unsafe withUnsafeMutableBytes { buffer in
            let start = unsafe buffer.baseAddress!.advanced(by: range.lowerBound)
            unsafe start.initializeMemory(as: UInt8.self, repeating: 0, count: range.count)
        }
    }

    /// Zeroes bytes from the given offset to the end of the buffer.
    ///
    /// - Parameter offset: The starting offset from which to zero.
    ///
    /// - Precondition: `offset >= 0`
    /// - Precondition: `offset <= count`
    @inlinable
    public mutating func zero(from offset: Int) {
        let size = Int(bitPattern: count.cardinal)
        precondition(offset >= 0 && offset <= size)
        zero(range: offset..<size)
    }
}
