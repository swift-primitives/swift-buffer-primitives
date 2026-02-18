import Testing
import Buffer_Ring_Primitives
import Buffer_Primitives_Test_Support

// Buffer.Ring is generic, so per [TEST-004] we use the parallel namespace
// pattern — @Suite in extensions of generic type specializations is silently
// not discovered by Swift Testing.

@Suite("Buffer.Ring")
struct RingGrowableTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
}

// MARK: - Unit

extension RingGrowableTests.Unit {

    @Test
    func `FIFO ordering`() {
        var buffer = Buffer<Int>.Ring(minimumCapacity: 4)
        buffer.push.back(10)
        buffer.push.back(20)
        buffer.push.back(30)

        #expect(buffer.count == 3)

        #expect(buffer.pop.front() == 10)
        #expect(buffer.pop.front() == 20)
        #expect(buffer.pop.front() == 30)
        #expect(buffer.isEmpty)
    }

    @Test
    func `wrap-around behavior`() {
        var buffer = Buffer<Int>.Ring(minimumCapacity: 4)

        // Fill exactly to slotCapacity worth of elements
        let cap = buffer.capacity.rawValue.rawValue
        var i: UInt = 0
        while i < cap {
            buffer.push.back(Int(i))
            i += 1
        }
        #expect(buffer.isFull)

        // Pop two, push two — forces wrap
        _ = buffer.pop.front()
        _ = buffer.pop.front()
        buffer.push.back(100)
        buffer.push.back(200)

        // Verify FIFO order after wrap
        #expect(buffer.pop.front() == 2)
        #expect(buffer.pop.front() == 3)
    }

    @Test
    func `growth doubles capacity`() {
        var buffer = Buffer<Int>.Ring(minimumCapacity: 2)
        let originalCap = buffer.capacity

        // Fill past capacity — triggers growth
        var i = 0
        let needed = Int(originalCap.rawValue.rawValue) + 1
        while i < needed {
            buffer.push.back(i * 10)
            i += 1
        }

        #expect(buffer.capacity.rawValue.rawValue > originalCap.rawValue.rawValue)

        // Verify all elements survived growth in FIFO order
        i = 0
        while i < needed {
            #expect(buffer.pop.front() == i * 10)
            i += 1
        }
    }

    @Test
    func `slotCapacity invariant — capacity from storage, not request`() {
        let buffer = Buffer<Int>.Ring(minimumCapacity: 3)
        // slotCapacity may be > 3 (ManagedBuffer rounds up)
        #expect(buffer.capacity.rawValue.rawValue >= 3)
    }

    @Test
    func `drain removes all elements in FIFO order`() {
        var buffer: Buffer<Int>.Ring = [10, 20, 30]
        var drained: [Int] = []
        buffer.drain { drained.append($0) }
        #expect(drained == [10, 20, 30])
        #expect(buffer.isEmpty)
    }

    @Test
    func `removeAll clears buffer`() {
        var buffer: Buffer<Int>.Ring = [1, 2, 3]
        buffer.remove.all()
        #expect(buffer.isEmpty)
        #expect(buffer.count == 0)
    }

    @Test
    func `reserveCapacity grows if needed`() {
        var buffer = Buffer<Int>.Ring(minimumCapacity: 2)
        buffer.reserveCapacity(Index<Int>.Count(Cardinal(100)))
        #expect(buffer.capacity.rawValue.rawValue >= 100)
    }

    @Test
    func `peekFront and peekBack (Copyable)`() {
        var buffer: Buffer<Int>.Ring = [10, 20, 30]
        #expect(buffer.peek.front == 10)
        #expect(buffer.peek.back == 30)

        // Peek doesn't remove
        #expect(buffer.count == 3)
    }

    @Test
    func `pushFront and popBack (deque behavior)`() {
        var buffer = Buffer<Int>.Ring(minimumCapacity: 4)
        buffer.push.front(10)
        buffer.push.front(20)

        #expect(buffer.pop.back() == 10)
        #expect(buffer.pop.back() == 20)
    }

    @Test
    func `Sequence.Protocol iteration (Copyable)`() {
        let buffer: Buffer<Int>.Ring = [10, 20, 30]
        var collected: [Int] = []
        let iter = buffer.makeIterator()
        var it = iter
        while let value = it.next() {
            collected.append(value)
        }
        #expect(collected == [10, 20, 30])
    }

    @Test
    func `single element`() {
        var buffer = Buffer<Int>.Ring(minimumCapacity: 1)
        buffer.push.back(42)
        #expect(buffer.count == 1)
        #expect(buffer.pop.front() == 42)
        #expect(buffer.isEmpty)
    }

    @Test
    func `withFront borrows first element`() {
        let buffer: Buffer<Int>.Ring = [10, 20, 30]
        let value = buffer.withFront { $0 }
        #expect(value == 10)
        #expect(buffer.count == 3)
    }

    @Test
    func `withBack borrows last element`() {
        let buffer: Buffer<Int>.Ring = [10, 20, 30]
        let value = buffer.withBack { $0 }
        #expect(value == 30)
        #expect(buffer.count == 3)
    }

    @Test
    func `forEach visits all elements in FIFO order`() {
        let buffer: Buffer<Int>.Ring = [10, 20, 30]
        var visited: [Int] = []
        buffer.forEach { visited.append($0) }
        #expect(visited == [10, 20, 30])
    }

    @Test
    func `checkpoint saves current position`() {
        var buffer: Buffer<Int>.Ring = [10, 20, 30]
        let cp = buffer.checkpoint
        #expect(cp.count == 3)
    }

    @Test
    func `compact reclaims unused capacity`() {
        var buffer = Buffer<Int>.Ring(minimumCapacity: 100)
        buffer.push.back(1)
        buffer.push.back(2)
        buffer.compact()
        #expect(buffer.capacity.rawValue.rawValue <= 4)
        #expect(buffer.pop.front() == 1)
        #expect(buffer.pop.front() == 2)
    }

    @Test
    func `underestimatedCount matches count`() {
        let buffer: Buffer<Int>.Ring = [10, 20, 30]
        #expect(buffer.underestimatedCount == 3)
    }
}

// MARK: - Edge Cases

extension RingGrowableTests.EdgeCase {

    @Test
    func `empty buffer operations`() {
        let buffer = Buffer<Int>.Ring(minimumCapacity: 4)
        #expect(buffer.isEmpty)
        #expect(buffer.count == 0)
        #expect(!buffer.isFull)
    }

    @Test
    func `pushBack on empty then popFront`() {
        var buffer = Buffer<Int>.Ring(minimumCapacity: 4)
        buffer.push.back(42)
        #expect(buffer.pop.front() == 42)
        #expect(buffer.isEmpty)
    }

    @Test
    func `checkpoint on empty buffer`() {
        let buffer = Buffer<Int>.Ring(minimumCapacity: 4)
        let cp = buffer.checkpoint
        #expect(cp.count == 0)
    }

    @Test
    func `reserveCapacity with zero is no-op`() {
        var buffer = Buffer<Int>.Ring(minimumCapacity: 4)
        let originalCap = buffer.capacity
        buffer.reserveCapacity(.zero)
        #expect(buffer.capacity == originalCap)
    }

    @Test
    func `compact on already-compact buffer`() {
        var buffer: Buffer<Int>.Ring = [1, 2, 3, 4]
        buffer.compact()
        // Should not crash; capacity should be >= count
        #expect(buffer.count == 4)
        #expect(buffer.pop.front() == 1)
    }
}

// MARK: - Integration

extension RingGrowableTests.Integration {

    @Test
    func `interleaved push/pop maintains order`() {
        var buffer = Buffer<Int>.Ring(minimumCapacity: 4)
        buffer.push.back(1)
        buffer.push.back(2)
        #expect(buffer.pop.front() == 1)
        buffer.push.back(3)
        #expect(buffer.pop.front() == 2)
        #expect(buffer.pop.front() == 3)
        #expect(buffer.isEmpty)
    }

    @Test
    func `checkpoint restore skips intermediate elements`() {
        var buffer = Buffer<Int>.Ring(minimumCapacity: 8)
        buffer.push.back(10)
        buffer.push.back(20)
        let cp = buffer.checkpoint
        buffer.push.back(30)
        buffer.push.back(40)

        buffer.restore(to: cp)
        #expect(buffer.count == 2)
        #expect(buffer.pop.front() == 10)
        #expect(buffer.pop.front() == 20)
        #expect(buffer.isEmpty)
    }

    @Test
    func `drain then reuse buffer`() {
        var buffer: Buffer<Int>.Ring = [10, 20, 30]
        buffer.drain { _ in }
        #expect(buffer.isEmpty)

        buffer.push.back(40)
        buffer.push.back(50)
        #expect(buffer.pop.front() == 40)
        #expect(buffer.pop.front() == 50)
    }

    @Test
    func `iterator exhaustion then re-iterate`() {
        let buffer: Buffer<Int>.Ring = [1, 2, 3]
        var iter1 = buffer.makeIterator()
        while let _ = iter1.next() {}

        // Second iteration on same buffer
        var iter2 = buffer.makeIterator()
        var collected: [Int] = []
        while let v = iter2.next() { collected.append(v) }
        #expect(collected == [1, 2, 3])
    }
}
