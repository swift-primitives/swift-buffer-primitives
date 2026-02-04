import Testing
import Buffer_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Ring.Bounded")
struct RingBoundedTests {

    @Test("full rejection — pushBack returns element when full")
    func fullRejection() {
        var buffer = Buffer<Int>.Ring.Bounded(minimumCapacity: 2)
        let cap = buffer.capacity.rawValue.rawValue

        // Fill to capacity
        var i: UInt = 0
        while i < cap {
            let rejected = buffer.pushBack(Int(i))
            #expect(rejected == nil)
            i += 1
        }
        #expect(buffer.isFull)

        // Next push is rejected
        let rejected = buffer.pushBack(999)
        #expect(rejected == 999)
    }

    @Test("full rejection — pushFront returns element when full")
    func fullRejectionFront() {
        var buffer = Buffer<Int>.Ring.Bounded(minimumCapacity: 2)
        let cap = buffer.capacity.rawValue.rawValue

        var i: UInt = 0
        while i < cap {
            _ = buffer.pushBack(Int(i))
            i += 1
        }

        let rejected = buffer.pushFront(999)
        #expect(rejected == 999)
    }

    @Test("capacity-of-1 ring")
    func capacityOfOne() {
        var buffer = Buffer<Int>.Ring.Bounded(minimumCapacity: 1)
        let rejected = buffer.pushBack(42)
        #expect(rejected == nil)
        #expect(buffer.isFull)

        let value = buffer.popFront()
        #expect(value == 42)
        #expect(buffer.isEmpty)
    }

    @Test("interleaved push/pop cycles")
    func interleaved() {
        var buffer = Buffer<Int>.Ring.Bounded(minimumCapacity: 3)
        _ = buffer.pushBack(1)
        _ = buffer.pushBack(2)
        #expect(buffer.popFront() == 1)
        _ = buffer.pushBack(3)
        #expect(buffer.popFront() == 2)
        _ = buffer.pushBack(4)
        #expect(buffer.popFront() == 3)
        #expect(buffer.popFront() == 4)
        #expect(buffer.isEmpty)
    }

    @Test("fill/drain cycle")
    func fillDrainCycle() {
        var buffer = Buffer<Int>.Ring.Bounded(minimumCapacity: 4)
        let cap = Int(buffer.capacity.rawValue.rawValue)

        // Fill
        var i = 0
        while i < cap {
            _ = buffer.pushBack(i)
            i += 1
        }
        #expect(buffer.isFull)

        // Drain
        var drained: [Int] = []
        buffer.drain { drained.append($0) }
        #expect(buffer.isEmpty)
        #expect(drained.count == cap)
    }

    @Test("peekFront and peekBack (Copyable)")
    func peekFrontBack() {
        var buffer = Buffer<Int>.Ring.Bounded.with([10, 20, 30], capacity: 4)
        #expect(buffer.peekFront == 10)
        #expect(buffer.peekBack == 30)
        #expect(buffer.count == 3)
    }

    @Test("removeAll clears buffer")
    func removeAll() {
        var buffer = Buffer<Int>.Ring.Bounded.with([1, 2, 3], capacity: 4)
        buffer.removeAll()
        #expect(buffer.isEmpty)
    }

    @Test("Sequence.Protocol iteration (Copyable)")
    func sequenceIteration() {
        let buffer = Buffer<Int>.Ring.Bounded.with([10, 20, 30], capacity: 4)
        var collected: [Int] = []
        var iter = buffer.makeIterator()
        while let value = iter.next() {
            collected.append(value)
        }
        #expect(collected == [10, 20, 30])
    }
}
