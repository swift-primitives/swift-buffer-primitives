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

import Testing
import Buffer_Primitives_Test_Support

// MARK: - Buffer.Ring Tests (Parallel Namespace per TEST-004)

/// Tests for `Buffer.Ring` - unbounded circular buffer.
///
/// Uses parallel namespace pattern because `Buffer.Ring` is generic.
/// See [TEST-004] for rationale.
@Suite("Buffer.Ring")
struct BufferRingTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
    @Suite(.serialized) struct Performance {}
}

// MARK: - Unit Tests

extension BufferRingTests.Unit {

    @Test
    func `init creates empty buffer`() {
        let ring = Buffer<Int>.Ring()

        #expect(ring.isEmpty)
        #expect(ring.count == .zero)
        #expect(ring.capacity == .zero)
    }

    @Test
    func `init with minimumCapacity creates empty buffer`() {
        let ring = Buffer<Int>.Ring(minimumCapacity: 16)

        #expect(ring.isEmpty)
        #expect(ring.count == .zero)
        // Capacity is zero until first push (lazy allocation)
        #expect(ring.capacity == .zero)
    }

    @Test
    func `push adds element to buffer`() {
        var ring = Buffer<Int>.Ring()

        ring.push(42)

        #expect(!ring.isEmpty)
        #expect(ring.count == 1)
        #expect(ring.peekFront() == 42)
    }

    @Test
    func `push multiple elements maintains FIFO order`() {
        var ring = Buffer<Int>.Ring()

        ring.push(1)
        ring.push(2)
        ring.push(3)

        #expect(ring.count == 3)
        #expect(ring.peekFront() == 1)
        #expect(ring.peekBack() == 3)
    }

    @Test
    func `popFront removes and returns oldest element`() {
        var ring = Buffer<Int>.Ring()
        ring.push(1)
        ring.push(2)
        ring.push(3)

        let first = ring.popFront()
        let second = ring.popFront()
        let third = ring.popFront()

        #expect(first == 1)
        #expect(second == 2)
        #expect(third == 3)
        #expect(ring.isEmpty)
    }

    @Test
    func `popBack removes and returns newest element`() {
        var ring = Buffer<Int>.Ring.with([1, 2, 3])

        let last = ring.popBack()
        let middle = ring.popBack()
        let first = ring.popBack()

        #expect(last == 3)
        #expect(middle == 2)
        #expect(first == 1)
        #expect(ring.isEmpty)
    }

    @Test
    func `peekFront returns copy without removing`() {
        var ring = Buffer<Int>.Ring()
        ring.push(42)
        ring.push(100)

        let peeked = ring.peekFront()

        #expect(peeked == 42)
        #expect(ring.count == 2)
    }

    @Test
    func `peekBack returns copy without removing`() {
        var ring = Buffer<Int>.Ring()
        ring.push(42)
        ring.push(100)

        let peeked = ring.peekBack()

        #expect(peeked == 100)
        #expect(ring.count == 2)
    }

    @Test
    func `withFront provides borrowing access`() {
        var ring = Buffer<Int>.Ring()
        ring.push(42)

        let result = ring.withFront { element in
            element * 2
        }

        #expect(result == 84)
        #expect(ring.count == 1)
    }

    @Test
    func `withBack provides borrowing access`() {
        var ring = Buffer<Int>.Ring()
        ring.push(1)
        ring.push(42)

        let result = ring.withBack { element in
            element * 2
        }

        #expect(result == 84)
        #expect(ring.count == 2)
    }

    @Test
    func `drain consumes all elements`() {
        var ring = Buffer<Int>.Ring()
        ring.push(1)
        ring.push(2)
        ring.push(3)
        var collected: [Int] = []

        ring.drain { element in
            collected.append(element)
        }

        #expect(collected == [1, 2, 3])
        #expect(ring.isEmpty)
    }

    @Test
    func `removeAll clears buffer`() {
        var ring = Buffer<Int>.Ring()
        ring.push(1)
        ring.push(2)
        ring.push(3)

        ring.removeAll()

        #expect(ring.isEmpty)
        #expect(ring.count == .zero)
    }

    @Test
    func `reserveCapacity ensures minimum capacity`() {
        var ring = Buffer<Int>.Ring()

        ring.reserveCapacity(100)

        // Capacity should be at least 100 after reservation
        #expect(ring.capacity >= 100)
    }
}

// MARK: - Edge Case Tests

extension BufferRingTests.EdgeCase {

    @Test
    func `popFront on empty buffer returns nil`() {
        var ring = Buffer<Int>.Ring()

        let result = ring.popFront()

        #expect(result == nil)
    }

    @Test
    func `popBack on empty buffer returns nil`() {
        var ring = Buffer<Int>.Ring()

        let result = ring.popBack()

        #expect(result == nil)
    }

    @Test
    func `peekFront on empty buffer returns nil`() {
        let ring = Buffer<Int>.Ring()

        let result = ring.peekFront()

        #expect(result == nil)
    }

    @Test
    func `peekBack on empty buffer returns nil`() {
        let ring = Buffer<Int>.Ring()

        let result = ring.peekBack()

        #expect(result == nil)
    }

    @Test
    func `withFront on empty buffer returns nil`() {
        let ring = Buffer<Int>.Ring()

        let result = ring.withFront { $0 }

        #expect(result == nil)
    }

    @Test
    func `withBack on empty buffer returns nil`() {
        let ring = Buffer<Int>.Ring()

        let result = ring.withBack { $0 }

        #expect(result == nil)
    }

    @Test
    func `drain on empty buffer does nothing`() {
        var ring = Buffer<Int>.Ring()
        var called = false

        ring.drain { _ in called = true }

        #expect(!called)
    }

    @Test
    func `buffer grows automatically when full`() {
        var ring = Buffer<Int>.Ring(minimumCapacity: 2)

        // Push beyond initial capacity
        for i in 0..<10 {
            ring.push(i)
        }

        #expect(ring.count == 10)
        #expect(ring.capacity >= 10)

        // Verify order preserved
        for i in 0..<10 {
            #expect(ring.popFront() == i)
        }
    }

    @Test
    func `interleaved push and pop maintains correctness`() {
        var ring = Buffer<Int>.Ring()

        ring.push(1)
        ring.push(2)
        #expect(ring.popFront() == 1)

        ring.push(3)
        ring.push(4)
        #expect(ring.popFront() == 2)
        #expect(ring.popFront() == 3)

        ring.push(5)
        #expect(ring.popFront() == 4)
        #expect(ring.popFront() == 5)
        #expect(ring.isEmpty)
    }

    @Test
    func `wrap-around maintains FIFO order`() {
        var ring = Buffer<Int>.Ring(minimumCapacity: 4)

        // Fill and partially drain to force wrap-around
        ring.push(1)
        ring.push(2)
        ring.push(3)
        ring.push(4)
        _ = ring.popFront()  // 1
        _ = ring.popFront()  // 2

        // Now push more to wrap around
        ring.push(5)
        ring.push(6)

        // Verify FIFO order
        #expect(ring.popFront() == 3)
        #expect(ring.popFront() == 4)
        #expect(ring.popFront() == 5)
        #expect(ring.popFront() == 6)
    }

    @Test
    func `single element push and pop`() {
        var ring = Buffer<Int>.Ring()

        ring.push(42)
        let value = ring.popFront()

        #expect(value == 42)
        #expect(ring.isEmpty)
    }
}

// MARK: - Integration Tests

extension BufferRingTests.Integration {

    @Test
    func `copy creates independent buffer when Element is Copyable`() {
        var original = Buffer<Int>.Ring()
        original.push(1)
        original.push(2)
        original.push(3)

        // Copy (shallow - shares storage)
        var copy = original

        // Mutate copy (this triggers CoW)
        _ = copy.popFront()
        copy.push(100)

        // Original should be unchanged (CoW ensures independence)
        #expect(original.count == 3)
        #expect(original.peekFront() == 1)
    }

    @Test
    func `large buffer operations`() {
        var ring = Buffer<Int>.Ring()

        // Push many elements
        for i in 0..<1000 {
            ring.push(i)
        }

        #expect(ring.count == 1000)

        // Pop and verify order
        for i in 0..<1000 {
            #expect(ring.popFront() == i)
        }

        #expect(ring.isEmpty)
    }
}

// MARK: - Performance Tests

extension BufferRingTests.Performance {

    @Test
    func `sequential push performance`() {
        var ring = Buffer<Int>.Ring(minimumCapacity: 10000)

        for i in 0..<10000 {
            ring.push(i)
        }

        #expect(ring.count == 10000)
    }

    @Test
    func `sequential pop performance`() {
        var ring = Buffer<Int>.Ring(minimumCapacity: 10000)
        for i in 0..<10000 {
            ring.push(i)
        }

        for _ in 0..<10000 {
            _ = ring.popFront()
        }

        #expect(ring.isEmpty)
    }
}
