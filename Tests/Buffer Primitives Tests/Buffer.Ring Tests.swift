import Testing
import Buffer_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Ring")
struct RingGrowableTests {

    @Test("FIFO ordering")
    func fifo() {
        var buffer = Buffer<Int>.Ring(minimumCapacity: 4)
        buffer.pushBack(10)
        buffer.pushBack(20)
        buffer.pushBack(30)

        #expect(buffer.count == 3)

        #expect(buffer.popFront() == 10)
        #expect(buffer.popFront() == 20)
        #expect(buffer.popFront() == 30)
        #expect(buffer.isEmpty)
    }

    @Test("wrap-around behavior")
    func wrapAround() {
        var buffer = Buffer<Int>.Ring(minimumCapacity: 4)

        // Fill exactly to slotCapacity worth of elements
        let cap = buffer.capacity.rawValue.rawValue
        var i: UInt = 0
        while i < cap {
            buffer.pushBack(Int(i))
            i += 1
        }
        #expect(buffer.isFull)

        // Pop two, push two — forces wrap
        _ = buffer.popFront()
        _ = buffer.popFront()
        buffer.pushBack(100)
        buffer.pushBack(200)

        // Verify FIFO order after wrap
        #expect(buffer.popFront() == 2)
        #expect(buffer.popFront() == 3)
    }

    @Test("growth doubles capacity")
    func growth() {
        var buffer = Buffer<Int>.Ring(minimumCapacity: 2)
        let originalCap = buffer.capacity

        // Fill past capacity — triggers growth
        var i = 0
        let needed = Int(originalCap.rawValue.rawValue) + 1
        while i < needed {
            buffer.pushBack(i * 10)
            i += 1
        }

        #expect(buffer.capacity.rawValue.rawValue > originalCap.rawValue.rawValue)

        // Verify all elements survived growth in FIFO order
        i = 0
        while i < needed {
            #expect(buffer.popFront() == i * 10)
            i += 1
        }
    }

    @Test("slotCapacity invariant — capacity from storage, not request")
    func slotCapacityInvariant() {
        let buffer = Buffer<Int>.Ring(minimumCapacity: 3)
        // slotCapacity may be > 3 (ManagedBuffer rounds up)
        #expect(buffer.capacity.rawValue.rawValue >= 3)
    }

    @Test("drain removes all elements in FIFO order")
    func drain() {
        var buffer = Buffer<Int>.Ring.with([10, 20, 30])
        var drained: [Int] = []
        buffer.drain { drained.append($0) }
        #expect(drained == [10, 20, 30])
        #expect(buffer.isEmpty)
    }

    @Test("removeAll clears buffer")
    func removeAll() {
        var buffer = Buffer<Int>.Ring.with([1, 2, 3])
        buffer.removeAll()
        #expect(buffer.isEmpty)
        #expect(buffer.count == 0)
    }

    @Test("reserveCapacity grows if needed")
    func reserveCapacity() {
        var buffer = Buffer<Int>.Ring(minimumCapacity: 2)
        buffer.reserveCapacity(Index<Element>.Count(Cardinal(100)))
        #expect(buffer.capacity.rawValue.rawValue >= 100)
    }

    @Test("peekFront and peekBack (Copyable)")
    func peekFrontBack() {
        var buffer = Buffer<Int>.Ring.with([10, 20, 30])
        #expect(buffer.peekFront == 10)
        #expect(buffer.peekBack == 30)

        // Peek doesn't remove
        #expect(buffer.count == 3)
    }

    @Test("pushFront and popBack (deque behavior)")
    func deque() {
        var buffer = Buffer<Int>.Ring(minimumCapacity: 4)
        buffer.pushFront(10)
        buffer.pushFront(20)

        #expect(buffer.popBack() == 10)
        #expect(buffer.popBack() == 20)
    }

    @Test("interleaved push/pop maintains order")
    func interleaved() {
        var buffer = Buffer<Int>.Ring(minimumCapacity: 4)
        buffer.pushBack(1)
        buffer.pushBack(2)
        #expect(buffer.popFront() == 1)
        buffer.pushBack(3)
        #expect(buffer.popFront() == 2)
        #expect(buffer.popFront() == 3)
        #expect(buffer.isEmpty)
    }

    @Test("Sequence.Protocol iteration (Copyable)")
    func sequenceIteration() {
        let buffer = Buffer<Int>.Ring.with([10, 20, 30])
        var collected: [Int] = []
        let iter = buffer.makeIterator()
        var it = iter
        while let value = it.next() {
            collected.append(value)
        }
        #expect(collected == [10, 20, 30])
    }

    @Test("single element")
    func singleElement() {
        var buffer = Buffer<Int>.Ring(minimumCapacity: 1)
        buffer.pushBack(42)
        #expect(buffer.count == 1)
        #expect(buffer.popFront() == 42)
        #expect(buffer.isEmpty)
    }

    @Test("empty buffer operations")
    func emptyOperations() {
        let buffer = Buffer<Int>.Ring(minimumCapacity: 4)
        #expect(buffer.isEmpty)
        #expect(buffer.count == 0)
        #expect(!buffer.isFull)
    }
}
