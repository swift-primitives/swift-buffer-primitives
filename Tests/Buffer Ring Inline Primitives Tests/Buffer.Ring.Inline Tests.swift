import Testing
import Buffer_Ring_Inline_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Ring.Inline")
struct RingBoundedInlineTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
}

// MARK: - Unit

extension RingBoundedInlineTests.Unit {

    @Test
    func `FIFO ordering`() throws {
        var buffer = Buffer<Int>.Ring.Inline<4>()
        _ = buffer.push.back(10)
        _ = buffer.push.back(20)
        _ = buffer.push.back(30)

        #expect(buffer.count == 3)

        #expect(buffer.pop.front() == 10)
        #expect(buffer.pop.front() == 20)
        #expect(buffer.pop.front() == 30)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `wrap-around behavior`() throws {
        var buffer = Buffer<Int>.Ring.Inline<4>()

        // Fill to capacity
        _ = buffer.push.back(0)
        _ = buffer.push.back(1)
        _ = buffer.push.back(2)
        _ = buffer.push.back(3)
        #expect(buffer.isFull == true)

        // Pop two, push two — forces wrap
        _ = buffer.pop.front()
        _ = buffer.pop.front()
        _ = buffer.push.back(100)
        _ = buffer.push.back(200)

        // Verify FIFO order after wrap
        #expect(buffer.pop.front() == 2)
        #expect(buffer.pop.front() == 3)
        #expect(buffer.pop.front() == 100)
        #expect(buffer.pop.front() == 200)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `pushFront and popBack (deque behavior)`() throws {
        var buffer = Buffer<Int>.Ring.Inline<4>()
        _ = buffer.push.front(10)
        _ = buffer.push.front(20)

        #expect(buffer.pop.back() == 10)
        #expect(buffer.pop.back() == 20)
    }

    @Test
    func `peekFront and peekBack (Copyable)`() throws {
        let buffer = try Buffer<Int>.Ring.Inline<8>([10, 20, 30])
        #expect(buffer.peek.front == 10)
        #expect(buffer.peek.back == 30)
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
        buffer.remove.all()
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
    func `checkpoint and restore`() throws {
        var buffer = Buffer<Int>.Ring.Inline<8>()
        _ = buffer.push.back(10)
        _ = buffer.push.back(20)
        let cp = buffer.checkpoint
        _ = buffer.push.back(30)
        _ = buffer.push.back(40)

        buffer.restore(to: cp)
        #expect(buffer.count == 2)
        #expect(buffer.pop.front() == 10)
        #expect(buffer.pop.front() == 20)
    }
}

// MARK: - Edge Cases

extension RingBoundedInlineTests.EdgeCase {

    @Test
    func `full rejection — pushBack returns element when full`() throws {
        var buffer = Buffer<Int>.Ring.Inline<4>()

        _ = buffer.push.back(0)
        _ = buffer.push.back(1)
        _ = buffer.push.back(2)
        _ = buffer.push.back(3)
        #expect(buffer.isFull == true)

        let rejected = buffer.push.back(999)
        #expect(rejected == 999)
    }

    @Test
    func `full rejection — pushFront returns element when full`() throws {
        var buffer = Buffer<Int>.Ring.Inline<4>()

        _ = buffer.push.back(0)
        _ = buffer.push.back(1)
        _ = buffer.push.back(2)
        _ = buffer.push.back(3)

        let rejected = buffer.push.front(999)
        #expect(rejected == 999)
    }
}

// MARK: - Integration

extension RingBoundedInlineTests.Integration {

    @Test
    func `interleaved push/pop cycles`() throws {
        var buffer = Buffer<Int>.Ring.Inline<4>()
        _ = buffer.push.back(1)
        _ = buffer.push.back(2)
        #expect(buffer.pop.front() == 1)
        _ = buffer.push.back(3)
        #expect(buffer.pop.front() == 2)
        _ = buffer.push.back(4)
        #expect(buffer.pop.front() == 3)
        #expect(buffer.pop.front() == 4)
        #expect(buffer.isEmpty == true)
    }
}
