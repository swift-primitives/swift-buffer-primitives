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

// MARK: - Buffer.Slots.Static Tests (Parallel Namespace per TEST-004)

/// Tests for `Buffer.Slots.Static` - index-addressable slot storage.
///
/// Uses parallel namespace pattern because `Buffer.Slots.Static` is generic.
@Suite("Buffer.Slots.Static")
struct BufferSlotsStaticTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
    @Suite(.serialized) struct Performance {}
}

// MARK: - Unit Tests

extension BufferSlotsStaticTests.Unit {

    @Test
    func `init creates empty slot store with specified capacity`() {
        let slots = Buffer<Int>.Slots.Static(capacity: 8)

        #expect(slots.isEmpty == true)
        #expect(slots.count == .zero)
        #expect(slots.capacity == 8)
        #expect(!slots.isFull == true)
    }

    @Test
    func `put stores element at specified index`() {
        var slots = Buffer<Int>.Slots.Static(capacity: 4)
        let index: Buffer<Int>.Index = .zero

        slots.put(42, at: index)

        #expect(!slots.isEmpty == true)
        #expect(slots.count == 1)
        #expect(slots.isOccupied(at: index) == true)
    }

    @Test
    func `take removes and returns element at index`() {
        var slots = Buffer<Int>.Slots.Static.with(capacity: 4, elements: [42])
        let index: Buffer<Int>.Index = .zero

        let value = slots.take(at: index)

        #expect(value == 42)
        #expect(slots.isEmpty == true)
        #expect(!slots.isOccupied(at: index) == true)
    }

    @Test
    func `withElement provides borrowing access`() {
        var slots = Buffer<Int>.Slots.Static.with(capacity: 4, elements: [42])
        let index: Buffer<Int>.Index = .zero

        let result = slots.withElement(at: index) { element in
            element * 2
        }

        #expect(result == 84)
        #expect(slots.count == 1)
    }

    @Test
    func `isOccupied returns correct state`() {
        var slots = Buffer<Int>.Slots.Static(capacity: 4)
        let index: Buffer<Int>.Index = .zero

        #expect(!slots.isOccupied(at: index) == true)

        slots.put(42, at: index)
        #expect(slots.isOccupied(at: index) == true)

        _ = slots.take(at: index)
        #expect(!slots.isOccupied(at: index) == true)
    }

    @Test
    func `drain consumes all occupied slots`() {
        var slots = Buffer<Int>.Slots.Static(capacity: 4)
        slots.put(1, at: Buffer<Int>.Index(Ordinal(0)))
        slots.put(2, at: Buffer<Int>.Index(Ordinal(2)))

        var collected: [Int] = []
        slots.drain { _, element in
            collected.append(element)
        }

        #expect(collected.sorted() == [1, 2])
        #expect(slots.isEmpty == true)
    }

    @Test
    func `removeAll clears all slots`() {
        var slots = Buffer<Int>.Slots.Static.with(capacity: 4, elements: [1, 2, 3])

        slots.removeAll()

        #expect(slots.isEmpty == true)
        #expect(slots.count == .zero)
    }

    @Test
    func `isFull returns true when all slots occupied`() {
        var slots = Buffer<Int>.Slots.Static(capacity: 3)

        slots.put(1, at: Buffer<Int>.Index(Ordinal(0)))
        slots.put(2, at: Buffer<Int>.Index(Ordinal(1)))
        #expect(!slots.isFull == true)

        slots.put(3, at: Buffer<Int>.Index(Ordinal(2)))
        #expect(slots.isFull == true)
    }

    @Test
    func `non-sequential indices work correctly`() {
        var slots = Buffer<Int>.Slots.Static(capacity: 8)

        slots.put(100, at: Buffer<Int>.Index(Ordinal(7)))
        slots.put(200, at: Buffer<Int>.Index(Ordinal(3)))
        slots.put(300, at: Buffer<Int>.Index(Ordinal(0)))

        #expect(slots.count == 3)
        #expect(slots.take(at: Buffer<Int>.Index(Ordinal(3))) == 200)
        #expect(slots.take(at: Buffer<Int>.Index(Ordinal(7))) == 100)
        #expect(slots.take(at: Buffer<Int>.Index(Ordinal(0))) == 300)
    }
}

// MARK: - Edge Case Tests

extension BufferSlotsStaticTests.EdgeCase {

    @Test
    func `drain on empty store does nothing`() {
        var slots = Buffer<Int>.Slots.Static(capacity: 4)
        var called = false

        slots.drain { _, _ in called = true }

        #expect(!called)
    }

    @Test
    func `capacity of 1 works correctly`() {
        var slots = Buffer<Int>.Slots.Static(capacity: 1)
        let index: Buffer<Int>.Index = .zero

        #expect(slots.isEmpty == true)
        #expect(!slots.isFull == true)

        slots.put(42, at: index)
        #expect(!slots.isEmpty == true)
        #expect(slots.isFull == true)

        let value = slots.take(at: index)
        #expect(value == 42)
        #expect(slots.isEmpty == true)
    }

    @Test
    func `sparse occupancy works correctly`() {
        var slots = Buffer<Int>.Slots.Static(capacity: 100)

        // Only occupy every 10th slot
        for i in stride(from: 0, to: 100, by: 10) {
            slots.put(i, at: Buffer<Int>.Index(Ordinal(UInt(i))))
        }

        #expect(slots.count == 10)

        // Verify occupancy
        for i in 0..<100 {
            let index = Buffer<Int>.Index(Ordinal(UInt(i)))
            if i % 10 == 0 {
                #expect(slots.isOccupied(at: index) == true)
            } else {
                #expect(!slots.isOccupied(at: index) == true)
            }
        }
    }

    @Test
    func `reuse slot after take`() {
        var slots = Buffer<Int>.Slots.Static(capacity: 4)
        let index: Buffer<Int>.Index = .zero

        slots.put(1, at: index)
        _ = slots.take(at: index)
        slots.put(2, at: index)

        #expect(slots.take(at: index) == 2)
    }
}

// MARK: - Integration Tests

extension BufferSlotsStaticTests.Integration {

    @Test
    func `fill and drain cycle`() {
        var slots = Buffer<Int>.Slots.Static(capacity: 8)

        // Fill
        for i in 0..<8 {
            slots.put(i, at: Buffer<Int>.Index(Ordinal(UInt(i))))
        }
        #expect(slots.isFull == true)

        // Drain
        var collected: [Int] = []
        slots.drain { collected.append($1) }

        #expect(collected.sorted() == Array(0..<8))
        #expect(slots.isEmpty == true)
    }

    @Test
    func `random access pattern`() {
        var slots = Buffer<Int>.Slots.Static(capacity: 16)

        // Put at various indices
        slots.put(100, at: Buffer<Int>.Index(Ordinal(5)))
        slots.put(200, at: Buffer<Int>.Index(Ordinal(10)))
        slots.put(300, at: Buffer<Int>.Index(Ordinal(15)))
        slots.put(400, at: Buffer<Int>.Index(Ordinal(0)))

        #expect(slots.count == 4)

        // Take in different order
        #expect(slots.take(at: Buffer<Int>.Index(Ordinal(10))) == 200)
        #expect(slots.take(at: Buffer<Int>.Index(Ordinal(0))) == 400)
        #expect(slots.take(at: Buffer<Int>.Index(Ordinal(15))) == 300)
        #expect(slots.take(at: Buffer<Int>.Index(Ordinal(5))) == 100)

        #expect(slots.isEmpty == true)
    }
}

// MARK: - Performance Tests

extension BufferSlotsStaticTests.Performance {

    @Test
    func `sequential put to capacity`() {
        var slots = Buffer<Int>.Slots.Static(capacity: 10000)

        for i in 0..<10000 {
            slots.put(i, at: Buffer<Int>.Index(Ordinal(UInt(i))))
        }

        #expect(slots.isFull == true)
    }

    @Test
    func `sequential take from full store`() {
        var slots = Buffer<Int>.Slots.Static.with(capacity: 10000, elements: Array(0..<10000))

        for i in 0..<10000 {
            _ = slots.take(at: Buffer<Int>.Index(Ordinal(UInt(i))))
        }

        #expect(slots.isEmpty == true)
    }
}
