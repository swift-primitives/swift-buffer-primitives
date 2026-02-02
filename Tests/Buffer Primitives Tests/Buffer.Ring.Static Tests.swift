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

// MARK: - Buffer.Ring.Static Tests (Parallel Namespace per TEST-004)

/// Tests for `Buffer.Ring.Static` - bounded circular buffer.
///
/// Uses parallel namespace pattern because `Buffer.Ring.Static` is generic.
/// Note: Buffer.Ring.Static is ~Copyable, so we test via observable properties [TEST-011].
@Suite("Buffer.Ring.Static")
struct BufferRingStaticTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
    @Suite(.serialized) struct Performance {}
}

// MARK: - Unit Tests

extension BufferRingStaticTests.Unit {

    @Test
    func `init creates empty buffer with specified capacity`() {
        let ring = Buffer<Int>.Ring.Static(capacity: 8)

        let count = ring.count
        let capacity = ring.capacity

        #expect(ring.isEmpty == true)
        #expect(count == .zero)
        #expect(capacity == 8)
        #expect(!ring.isFull == true)
    }

    @Test
    func `push adds element to buffer`() {
        var ring = Buffer<Int>.Ring.Static(capacity: 4)

        let rejected = ring.push(42)

        let count = ring.count
        let front = ring.peekFront()

        #expect(rejected == nil)
        #expect(!ring.isEmpty == true)
        #expect(count == 1)
        #expect(front == 42)
    }

    @Test
    func `push multiple elements maintains FIFO order`() {
        var ring = Buffer<Int>.Ring.Static(capacity: 4)

        _ = ring.push(1)
        _ = ring.push(2)
        _ = ring.push(3)

        let count = ring.count
        let front = ring.peekFront()
        let back = ring.peekBack()

        #expect(count == 3)
        #expect(front == 1)
        #expect(back == 3)
    }

    @Test
    func `popFront removes and returns oldest element`() {
        var ring = Buffer<Int>.Ring.Static.with(capacity: 4, elements: [1, 2, 3])

        let first = ring.popFront()
        let second = ring.popFront()
        let third = ring.popFront()

        #expect(first == 1)
        #expect(second == 2)
        #expect(third == 3)
        #expect(ring.isEmpty == true)
    }

    @Test
    func `popBack removes and returns newest element`() {
        var ring = Buffer<Int>.Ring.Static.with(capacity: 4, elements: [1, 2, 3])

        let last = ring.popBack()
        let middle = ring.popBack()
        let first = ring.popBack()

        #expect(last == 3)
        #expect(middle == 2)
        #expect(first == 1)
        #expect(ring.isEmpty == true)
    }

    @Test
    func `peekFront returns copy without removing`() {
        let ring = Buffer<Int>.Ring.Static.with(capacity: 4, elements: [42, 100])

        let peeked = ring.peekFront()
        let count = ring.count

        #expect(peeked == 42)
        #expect(count == 2)
    }

    @Test
    func `peekBack returns copy without removing`() {
        let ring = Buffer<Int>.Ring.Static.with(capacity: 4, elements: [42, 100])

        let peeked = ring.peekBack()
        let count = ring.count

        #expect(peeked == 100)
        #expect(count == 2)
    }

    @Test
    func `withFront provides borrowing access`() {
        let ring = Buffer<Int>.Ring.Static.with(capacity: 4, elements: [42])

        let result = ring.withFront { element in
            element * 2
        }
        let count = ring.count

        #expect(result == 84)
        #expect(count == 1)
    }

    @Test
    func `withBack provides borrowing access`() {
        let ring = Buffer<Int>.Ring.Static.with(capacity: 4, elements: [1, 42])

        let result = ring.withBack { element in
            element * 2
        }
        let count = ring.count

        #expect(result == 84)
        #expect(count == 2)
    }

    @Test
    func `drain consumes all elements`() {
        var ring = Buffer<Int>.Ring.Static.with(capacity: 4, elements: [1, 2, 3])
        var collected: [Int] = []

        ring.drain { element in
            collected.append(element)
        }


        #expect(collected == [1, 2, 3])
        #expect(ring.isEmpty == true)
    }

    @Test
    func `removeAll clears buffer`() {
        var ring = Buffer<Int>.Ring.Static.with(capacity: 4, elements: [1, 2, 3])

        ring.removeAll()

        let count = ring.count

        #expect(ring.isEmpty == true)
        #expect(count == .zero)
    }

    @Test
    func `isFull returns true when buffer is at capacity`() {
        var ring = Buffer<Int>.Ring.Static(capacity: 3)

        _ = ring.push(1)
        _ = ring.push(2)
        let notFullYet = ring.isFull

        _ = ring.push(3)
        let nowFull = ring.isFull

        #expect(!notFullYet)
        #expect(nowFull)
    }
}

// MARK: - Edge Case Tests

extension BufferRingStaticTests.EdgeCase {

    @Test
    func `push when full returns rejected element`() {
        var ring = Buffer<Int>.Ring.Static.with(capacity: 2, elements: [1, 2])

        let rejected = ring.push(3)
        let count = ring.count

        #expect(rejected == 3)
        #expect(count == 2)
        #expect(ring.isFull == true)
    }

    @Test
    func `popFront on empty buffer returns nil`() {
        var ring = Buffer<Int>.Ring.Static(capacity: 4)

        let result = ring.popFront()

        #expect(result == nil)
    }

    @Test
    func `popBack on empty buffer returns nil`() {
        var ring = Buffer<Int>.Ring.Static(capacity: 4)

        let result = ring.popBack()

        #expect(result == nil)
    }

    @Test
    func `peekFront on empty buffer returns nil`() {
        let ring = Buffer<Int>.Ring.Static(capacity: 4)

        let result = ring.peekFront()

        #expect(result == nil)
    }

    @Test
    func `peekBack on empty buffer returns nil`() {
        let ring = Buffer<Int>.Ring.Static(capacity: 4)

        let result = ring.peekBack()

        #expect(result == nil)
    }

    @Test
    func `withFront on empty buffer returns nil`() {
        let ring = Buffer<Int>.Ring.Static(capacity: 4)

        let result = ring.withFront { $0 }

        #expect(result == nil)
    }

    @Test
    func `withBack on empty buffer returns nil`() {
        let ring = Buffer<Int>.Ring.Static(capacity: 4)

        let result = ring.withBack { $0 }

        #expect(result == nil)
    }

    @Test
    func `drain on empty buffer does nothing`() {
        var ring = Buffer<Int>.Ring.Static(capacity: 4)
        var called = false

        ring.drain { _ in called = true }

        #expect(!called)
    }

    @Test
    func `interleaved push and pop maintains correctness`() {
        var ring = Buffer<Int>.Ring.Static(capacity: 4)

        _ = ring.push(1)
        _ = ring.push(2)
        let pop1 = ring.popFront()

        _ = ring.push(3)
        _ = ring.push(4)
        let pop2 = ring.popFront()
        let pop3 = ring.popFront()

        _ = ring.push(5)
        let pop4 = ring.popFront()
        let pop5 = ring.popFront()

        #expect(pop1 == 1)
        #expect(pop2 == 2)
        #expect(pop3 == 3)
        #expect(pop4 == 4)
        #expect(pop5 == 5)
        #expect(ring.isEmpty == true)
    }

    @Test
    func `wrap-around maintains FIFO order`() {
        var ring = Buffer<Int>.Ring.Static(capacity: 4)

        // Fill completely
        _ = ring.push(1)
        _ = ring.push(2)
        _ = ring.push(3)
        _ = ring.push(4)

        // Pop two to make room
        _ = ring.popFront()  // 1
        _ = ring.popFront()  // 2

        // Push two more (will wrap around)
        _ = ring.push(5)
        _ = ring.push(6)

        // Verify FIFO order
        let a = ring.popFront()
        let b = ring.popFront()
        let c = ring.popFront()
        let d = ring.popFront()

        #expect(a == 3)
        #expect(b == 4)
        #expect(c == 5)
        #expect(d == 6)
    }

    @Test
    func `capacity of 1 works correctly`() {
        var ring = Buffer<Int>.Ring.Static(capacity: 1)

        let isEmpty1 = ring.isEmpty
        let isFull1 = ring.isFull

        _ = ring.push(42)
        let isEmpty2 = ring.isEmpty
        let isFull2 = ring.isFull

        let rejected = ring.push(100)

        let value = ring.popFront()
        let isEmpty3 = ring.isEmpty

        #expect(isEmpty1)
        #expect(!isFull1)
        #expect(!isEmpty2)
        #expect(isFull2)
        #expect(rejected == 100)
        #expect(value == 42)
        #expect(isEmpty3)
    }
}

// MARK: - Integration Tests

extension BufferRingStaticTests.Integration {

    @Test
    func `fill and drain cycle`() {
        var ring = Buffer<Int>.Ring.Static(capacity: 8)

        // Fill
        for i in 0..<8 {
            _ = ring.push(i)
        }

        // Drain
        var collected: [Int] = []
        ring.drain { collected.append($0) }


        #expect(!ring.isFull == true)
        #expect(collected == Array(0..<8))
        #expect(ring.isEmpty == true)
    }

    @Test
    func `multiple fill and drain cycles`() {
        var ring = Buffer<Int>.Ring.Static(capacity: 4)

        for cycle in 0..<10 {
            // Fill
            for i in 0..<4 {
                _ = ring.push(cycle * 100 + i)
            }

            // Drain
            for i in 0..<4 {
                let value = ring.popFront()
                #expect(value == cycle * 100 + i)
            }
        }

        #expect(ring.isEmpty == true)
    }
}

// MARK: - Performance Tests

extension BufferRingStaticTests.Performance {

    @Test
    func `sequential push to capacity`() {
        var ring = Buffer<Int>.Ring.Static(capacity: 10000)

        for i in 0..<10000 {
            _ = ring.push(i)
        }

        #expect(ring.isFull == true)
    }

    @Test
    func `sequential pop from full buffer`() {
        var ring = Buffer<Int>.Ring.Static.with(capacity: 10000, elements: Array(0..<10000))

        for _ in 0..<10000 {
            _ = ring.popFront()
        }

        #expect(ring.isEmpty == true)
    }
}
