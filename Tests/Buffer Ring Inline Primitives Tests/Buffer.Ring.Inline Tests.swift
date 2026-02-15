import Testing
import Buffer_Ring_Inline_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Ring.Inline")
struct RingBoundedInlineTests {

    @Test
    func `FIFO ordering`() throws {
        var buffer = Buffer<Int>.Ring.Inline<4>()
        _ = buffer.pushBack(10)
        _ = buffer.pushBack(20)
        _ = buffer.pushBack(30)

        #expect(buffer.count == 3)

        #expect(buffer.popFront() == 10)
        #expect(buffer.popFront() == 20)
        #expect(buffer.popFront() == 30)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `wrap-around behavior`() throws {
        var buffer = Buffer<Int>.Ring.Inline<4>()

        // Fill to capacity
        _ = buffer.pushBack(0)
        _ = buffer.pushBack(1)
        _ = buffer.pushBack(2)
        _ = buffer.pushBack(3)
        #expect(buffer.isFull == true)

        // Pop two, push two — forces wrap
        _ = buffer.popFront()
        _ = buffer.popFront()
        _ = buffer.pushBack(100)
        _ = buffer.pushBack(200)

        // Verify FIFO order after wrap
        #expect(buffer.popFront() == 2)
        #expect(buffer.popFront() == 3)
        #expect(buffer.popFront() == 100)
        #expect(buffer.popFront() == 200)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `full rejection — pushBack returns element when full`() throws {
        var buffer = Buffer<Int>.Ring.Inline<4>()

        _ = buffer.pushBack(0)
        _ = buffer.pushBack(1)
        _ = buffer.pushBack(2)
        _ = buffer.pushBack(3)
        #expect(buffer.isFull == true)

        let rejected = buffer.pushBack(999)
        #expect(rejected == 999)
    }

    @Test
    func `full rejection — pushFront returns element when full`() throws {
        var buffer = Buffer<Int>.Ring.Inline<4>()

        _ = buffer.pushBack(0)
        _ = buffer.pushBack(1)
        _ = buffer.pushBack(2)
        _ = buffer.pushBack(3)

        let rejected = buffer.pushFront(999)
        #expect(rejected == 999)
    }

    @Test
    func `pushFront and popBack (deque behavior)`() throws {
        var buffer = Buffer<Int>.Ring.Inline<4>()
        _ = buffer.pushFront(10)
        _ = buffer.pushFront(20)

        #expect(buffer.popBack() == 10)
        #expect(buffer.popBack() == 20)
    }

    @Test
    func `peekFront and peekBack (Copyable)`() throws {
        let buffer = try Buffer<Int>.Ring.Inline<8>([10, 20, 30])
        #expect(buffer.peekFront == 10)
        #expect(buffer.peekBack == 30)
        #expect(buffer.count == 3)
    }

    @Test
    func `drain removes all elements in FIFO order`() throws {
        var buffer = try Buffer<Int>.Ring.Inline<8>([10, 20, 30])
        var drained: [Int] = []
        buffer.drain { drained.append($0) }
        #expect(drained == [10, 20, 30])
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `removeAll clears buffer`() throws {
        var buffer = try Buffer<Int>.Ring.Inline<8>([1, 2, 3])
        buffer.removeAll()
        #expect(buffer.isEmpty == true)
        #expect(buffer.count == 0)
    }

    @Test
    func `Sequence.Protocol iteration (Copyable)`() throws {
        let buffer = try Buffer<Int>.Ring.Inline<8>([10, 20, 30])
        var collected: [Int] = []
        var iter = buffer.makeIterator()
        while let value = iter.next() {
            collected.append(value)
        }
        #expect(collected == [10, 20, 30])
    }

    @Test
    func `interleaved push/pop cycles`() throws {
        var buffer = Buffer<Int>.Ring.Inline<4>()
        _ = buffer.pushBack(1)
        _ = buffer.pushBack(2)
        #expect(buffer.popFront() == 1)
        _ = buffer.pushBack(3)
        #expect(buffer.popFront() == 2)
        _ = buffer.pushBack(4)
        #expect(buffer.popFront() == 3)
        #expect(buffer.popFront() == 4)
        #expect(buffer.isEmpty == true)
    }
}
