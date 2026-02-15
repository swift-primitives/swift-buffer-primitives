import Testing
import Buffer_Ring_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Ring.Bounded")
struct RingBoundedTests {

    @Test
    func `full rejection — pushBack returns element when full`() {
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

    @Test
    func `full rejection — pushFront returns element when full`() {
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

    @Test
    func `capacity-of-1 ring`() {
        var buffer = Buffer<Int>.Ring.Bounded(minimumCapacity: 1)
        let rejected = buffer.pushBack(42)
        #expect(rejected == nil)
        #expect(buffer.isFull)

        let value = buffer.popFront()
        #expect(value == 42)
        #expect(buffer.isEmpty)
    }

    @Test
    func `interleaved push/pop cycles`() {
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

    @Test
    func `fill/drain cycle`() {
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

    @Test
    func `peekFront and peekBack (Copyable)`() throws {
        var buffer = try Buffer<Int>.Ring.Bounded([10, 20, 30], capacity: 4)
        #expect(buffer.peekFront == 10)
        #expect(buffer.peekBack == 30)
        #expect(buffer.count == 3)
    }

    @Test
    func `removeAll clears buffer`() throws {
        var buffer = try Buffer<Int>.Ring.Bounded([1, 2, 3], capacity: 4)
        buffer.removeAll()
        #expect(buffer.isEmpty)
    }

    @Test
    func `Sequence.Protocol iteration (Copyable)`() throws {
        let buffer = try Buffer<Int>.Ring.Bounded([10, 20, 30], capacity: 4)
        var collected: [Int] = []
        var iter = buffer.makeIterator()
        while let value = iter.next() {
            collected.append(value)
        }
        #expect(collected == [10, 20, 30])
    }
}
