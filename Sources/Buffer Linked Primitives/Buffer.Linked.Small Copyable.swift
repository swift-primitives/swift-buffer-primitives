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
        switch _heapBuffer {
        case .some(let heap): return heap.first
        case .none: return _inlineBuffer.first
        }
    }

    /// Returns the last element, or `nil` if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var last: Element? {
        switch _heapBuffer {
        case .some(let heap): return heap.last
        case .none: return _inlineBuffer.last
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
        guard _heapBuffer != nil else { return false }
        return heap.ensureUnique()
    }
}
