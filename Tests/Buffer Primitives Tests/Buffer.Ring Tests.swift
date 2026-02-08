import Testing
import Buffer_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Ring")
struct RingGrowableTests {

    @Test
    func `FIFO ordering`() {
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

    @Test
    func `wrap-around behavior`() {
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

    @Test
    func `growth doubles capacity`() {
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
        buffer.removeAll()
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
        let buffer: Buffer<Int>.Ring = [10, 20, 30]
        #expect(buffer.peekFront == 10)
        #expect(buffer.peekBack == 30)

        // Peek doesn't remove
        #expect(buffer.count == 3)
    }

    @Test
    func `pushFront and popBack (deque behavior)`() {
        var buffer = Buffer<Int>.Ring(minimumCapacity: 4)
        buffer.pushFront(10)
        buffer.pushFront(20)

        #expect(buffer.popBack() == 10)
        #expect(buffer.popBack() == 20)
    }

    @Test
    func `interleaved push/pop maintains order`() {
        var buffer = Buffer<Int>.Ring(minimumCapacity: 4)
        buffer.pushBack(1)
        buffer.pushBack(2)
        #expect(buffer.popFront() == 1)
        buffer.pushBack(3)
        #expect(buffer.popFront() == 2)
        #expect(buffer.popFront() == 3)
        #expect(buffer.isEmpty)
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
        buffer.pushBack(42)
        #expect(buffer.count == 1)
        #expect(buffer.popFront() == 42)
        #expect(buffer.isEmpty)
    }

    @Test
    func `empty buffer operations`() {
        let buffer = Buffer<Int>.Ring(minimumCapacity: 4)
        #expect(buffer.isEmpty)
        #expect(buffer.count == 0)
        #expect(!buffer.isFull)
    }
}
