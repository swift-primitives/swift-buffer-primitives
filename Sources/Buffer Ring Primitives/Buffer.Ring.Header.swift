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

extension Buffer.Ring.Header where Element: ~Copyable {
    /// Advances head after dequeue, wrapping at capacity.
    ///
    /// - Parameter capacity: The buffer capacity.
    /// - Precondition: count > 0
    @inlinable
    public mutating func advanceHead(capacity: Index<Element>.Count) {
        head = Buffer.Ring.successor(of: head, wrapping: capacity)
        count = count.subtract.saturating(.one)
    }

    /// Advances tail after enqueue, wrapping at capacity.
    ///
    /// - Parameter capacity: The buffer capacity.
    /// - Precondition: count < capacity
    @inlinable
    public mutating func advanceTail(capacity: Index<Element>.Count) {
        tail = Buffer.Ring.successor(of: tail, wrapping: capacity)
        count = count + .one
    }

    /// Retreats head before enqueue at front, wrapping at capacity.
    ///
    /// Used by Deque for prepend operations.
    ///
    /// - Parameter capacity: The buffer capacity.
    /// - Precondition: count < capacity
    @inlinable
    public mutating func retreatHead(capacity: Index<Element>.Count) {
        head = Buffer.Ring.predecessor(of: head, wrapping: capacity)
        count = count + .one
    }

    /// Retreats tail before dequeue from back, wrapping at capacity.
    ///
    /// Used by Deque for pop-back operations.
    ///
    /// - Parameter capacity: The buffer capacity.
    /// - Precondition: count > 0
    @inlinable
    public mutating func retreatTail(capacity: Index<Element>.Count) {
        tail = Buffer.Ring.predecessor(of: tail, wrapping: capacity)
        count = count.subtract.saturating(.one)
    }
}


