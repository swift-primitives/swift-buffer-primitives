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

extension Buffer.Ring.Header.Cyclic where Element: ~Copyable {
    /// Whether the buffer is empty.
    @inlinable
    public var isEmpty: Bool { count == .zero }

    /// Whether the buffer is full.
    @inlinable
    public var isFull: Bool { Int(bitPattern: count) == capacity }

    /// Converts the head position to a linear index.
    @inlinable
    public var headIndex: Buffer.Index {
        Buffer.Index(Ordinal(head.rawValue.position.rawValue))
    }

    /// Converts the tail position to a linear index.
    @inlinable
    public var tailIndex: Buffer.Index {
        Buffer.Index(Ordinal(tail.rawValue.position.rawValue))
    }
}


// MARK: - Cyclic Header Operations

extension Buffer.Ring.Header.Cyclic where Element: ~Copyable {
    /// Advances head after dequeue.
    ///
    /// The cyclic index wraps automatically at capacity.
    ///
    /// - Precondition: count > 0
    @inlinable
    public mutating func advanceHead() {
        head += .one
        count = count.subtract.saturating(.one)
    }

    /// Advances tail after enqueue.
    ///
    /// The cyclic index wraps automatically at capacity.
    ///
    /// - Precondition: count < capacity
    @inlinable
    public mutating func advanceTail() {
        tail += .one
        count = count + .one
    }

    /// Retreats head before prepend (for deque operations).
    ///
    /// The cyclic index wraps automatically at capacity.
    ///
    /// - Precondition: count < capacity
    @inlinable
    public mutating func retreatHead() {
        head -= .one
        count = count + .one
    }

    /// Retreats tail before pop-back (for deque operations).
    ///
    /// The cyclic index wraps automatically at capacity.
    ///
    /// - Precondition: count > 0
    @inlinable
    public mutating func retreatTail() {
        tail -= .one
        count = count.subtract.saturating(.one)
    }

    /// Resets the header to empty state.
    @inlinable
    public mutating func reset() {
        head = .init(__unchecked: 0)
        tail = .init(__unchecked: 0)
        count = .zero
    }
}

