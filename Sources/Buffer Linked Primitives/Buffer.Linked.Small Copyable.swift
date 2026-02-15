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

public import Buffer_Primitives_Core

// MARK: - Convenience Accessors

extension Buffer.Linked.Small where Element: Copyable {
    /// Returns the first element, or `nil` if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var first: Element? {
        switch _storage {
        case .heap(let heap): return heap.first
        case .inline(let buf): return buf.first
        }
    }

    /// Returns the last element, or `nil` if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var last: Element? {
        switch _storage {
        case .heap(let heap): return heap.last
        case .inline(let buf): return buf.last
        }
    }
}

// MARK: - CoW Support

extension Buffer.Linked.Small where Element: Copyable {
    /// Ensures the heap storage is uniquely referenced, copying if needed.
    ///
    /// Only relevant in heap mode. In inline mode, the buffer is always unique
    /// (value-type storage). Returns `true` if a copy was made; `false` if
    /// already unique or still inline.
    @inlinable
    @discardableResult
    public mutating func ensureUnique() -> Bool {
        switch _storage {
        case .inline(var buf):
            self = Self(_storage: .inline(consume buf))
            return false
        case .heap(var buf):
            let copied = buf.ensureUnique()
            self = Self(_storage: .heap(consume buf))
            return copied
        }
    }
}
