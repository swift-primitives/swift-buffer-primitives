import Testing
import Buffer_Ring_Inline_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Ring.Small")
struct RingSmallTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
}

// MARK: - Unit

extension RingSmallTests.Unit {

    @Test
    func `starts in inline mode`() {
        let buffer = Buffer<Int>.Ring.Small<4>()
        #expect(buffer.isEmpty == true)
        #expect(buffer.count == .zero)
        #expect(buffer.isSpilled == false)
    }

    @Test
    func `pushBack within inline capacity stays inline`() {
        var buffer = Buffer<Int>.Ring.Small<4>()
        buffer.push.back(10)
        buffer.push.back(20)
        buffer.push.back(30)

        #expect(buffer.count == 3)
        #expect(buffer.isSpilled == false)
    }

    @Test
    func `spill to heap when inline is full`() {
        var buffer = Buffer<Int>.Ring.Small<2>()
        buffer.push.back(10)
        buffer.push.back(20)
        #expect(buffer.isSpilled == false)

        buffer.push.back(30)
        #expect(buffer.isSpilled == true)
        #expect(buffer.count == 3)
    }

    @Test
    func `elements survive spill — FIFO order preserved`() {
        var buffer = Buffer<Int>.Ring.Small<2>()
        buffer.push.back(10)
        buffer.push.back(20)
        #expect(buffer.isSpilled == false)

        buffer.push.back(30)
        #expect(buffer.isSpilled == true)

        #expect(buffer.pop.front() == 10)
        #expect(buffer.pop.front() == 20)
        #expect(buffer.pop.front() == 30)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `pushBack and popFront after spill`() {
        var buffer = Buffer<Int>.Ring.Small<2>()
        buffer.push.back(10)
        buffer.push.back(20)
        buffer.push.back(30) // triggers spill
        #expect(buffer.isSpilled == true)

        buffer.push.back(40)
        buffer.push.back(50)

        #expect(buffer.pop.front() == 10)
        #expect(buffer.pop.front() == 20)
        #expect(buffer.pop.front() == 30)
        #expect(buffer.pop.front() == 40)
        #expect(buffer.pop.front() == 50)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `pushFront and popBack after spill`() {
        var buffer = Buffer<Int>.Ring.Small<2>()
        buffer.push.back(10)
        buffer.push.back(20)
        buffer.push.back(30) // triggers spill
        #expect(buffer.isSpilled == true)

        buffer.push.front(5)
        #expect(buffer.pop.back() == 30)
        #expect(buffer.pop.back() == 20)
        #expect(buffer.pop.back() == 10)
        #expect(buffer.pop.back() == 5)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `removeAll resets to inline mode`() {
        var buffer = Buffer<Int>.Ring.Small<2>()
        buffer.push.back(10)
        buffer.push.back(20)
        buffer.push.back(30)
        #expect(buffer.isSpilled == true)

        buffer.remove.all()
        #expect(buffer.isEmpty == true)
        #expect(buffer.isSpilled == false)
    }

    @Test
    func `removeAll keepingCapacity stays in heap mode`() {
        var buffer = Buffer<Int>.Ring.Small<2>()
        buffer.push.back(10)
        buffer.push.back(20)
        buffer.push.back(30)
        #expect(buffer.isSpilled == true)

        buffer.remove.all(keepingCapacity: true)
        #expect(buffer.isEmpty == true)
        #expect(buffer.isSpilled == true)
    }

    @Test
    func `double-ended operations in inline mode`() {
        var buffer = Buffer<Int>.Ring.Small<4>()
        buffer.push.front(10)
        buffer.push.back(20)
        buffer.push.front(5)
        buffer.push.back(25)

        // Order: 5, 10, 20, 25
        #expect(buffer.peek.front == 5)
        #expect(buffer.peek.back == 25)
        #expect(buffer.pop.front() == 5)
        #expect(buffer.pop.back() == 25)
        #expect(buffer.pop.front() == 10)
        #expect(buffer.pop.back() == 20)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `double-ended operations in heap mode`() {
        var buffer = Buffer<Int>.Ring.Small<2>()
        buffer.push.back(10)
        buffer.push.back(20)
        buffer.push.back(30) // triggers spill

        buffer.push.front(5)
        buffer.push.back(35)

        // Order: 5, 10, 20, 30, 35
        #expect(buffer.peek.front == 5)
        #expect(buffer.peek.back == 35)
        #expect(buffer.pop.front() == 5)
        #expect(buffer.pop.back() == 35)
        #expect(buffer.count == 3)
    }

    @Test
    func `ensureUnique in heap mode uniquely owned`() {
        var buffer = Buffer<Int>.Ring.Small<2>()
        buffer.push.back(10)
        buffer.push.back(20)
        buffer.push.back(30)
        #expect(buffer.isSpilled == true)

        // Uniquely owned heap storage — no copy needed
        let didCopy = buffer.ensureUnique()
        #expect(didCopy == false)
    }

    @Test
    func `ensureUnique in inline mode returns false`() {
        var buffer = Buffer<Int>.Ring.Small<4>()
        buffer.push.back(10)

        let didCopy = buffer.ensureUnique()
        #expect(didCopy == false)
    }

    @Test
    func `peekFront and peekBack in inline mode`() {
        var buffer = Buffer<Int>.Ring.Small<4>()
        buffer.push.back(10)
        buffer.push.back(20)
        buffer.push.back(30)

        #expect(buffer.peek.front == 10)
        #expect(buffer.peek.back == 30)
        #expect(buffer.count == 3)
    }

    @Test
    func `drain removes all in FIFO order`() {
        var buffer = Buffer<Int>.Ring.Small<4>()
        buffer.push.back(10)
        buffer.push.back(20)
        buffer.push.back(30)

        var drained: [Int] = []
        buffer.drain { drained.append($0) }
        #expect(drained == [10, 20, 30])
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `isSpilled false initially`() {
        let buffer = Buffer<Int>.Ring.Small<8>()
        #expect(buffer.isSpilled == false)
    }

    @Test
    func `isSpilled true after growth`() {
        var buffer = Buffer<Int>.Ring.Small<2>()
        buffer.push.back(1)
        buffer.push.back(2)
        buffer.push.back(3)
        #expect(buffer.isSpilled == true)
    }

    @Test
    func `checkpoint saves position`() {
        var buffer = Buffer<Int>.Ring.Small<4>()
        buffer.push.back(10)
        buffer.push.back(20)
        let cp = buffer.checkpoint
        #expect(cp.count == 2)
    }
}

// MARK: - Edge Cases

extension RingSmallTests.EdgeCase {

    @Test
    func `wrap-around in inline mode`() {
        var buffer = Buffer<Int>.Ring.Small<4>()
        buffer.push.back(0)
        buffer.push.back(1)
        buffer.push.back(2)
        buffer.push.back(3)
        #expect(buffer.isFull == true)

        _ = buffer.pop.front()
        _ = buffer.pop.front()
        buffer.push.back(100)
        buffer.push.back(200)

        #expect(buffer.pop.front() == 2)
        #expect(buffer.pop.front() == 3)
        #expect(buffer.pop.front() == 100)
        #expect(buffer.pop.front() == 200)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `removeAll keepingCapacity false resets to inline`() {
        var buffer = Buffer<Int>.Ring.Small<2>()
        buffer.push.back(10)
        buffer.push.back(20)
        buffer.push.back(30)
        #expect(buffer.isSpilled == true)

        buffer.remove.all(keepingCapacity: false)
        #expect(buffer.isEmpty == true)
        #expect(buffer.isSpilled == false)
    }

    @Test
    func `restore to checkpoint in inline mode`() {
        var buffer = Buffer<Int>.Ring.Small<8>()
        buffer.push.back(10)
        buffer.push.back(20)
        let cp = buffer.checkpoint
        buffer.push.back(30)
        buffer.push.back(40)

        buffer.restore(to: cp)
        #expect(buffer.count == 2)
        #expect(buffer.pop.front() == 10)
        #expect(buffer.pop.front() == 20)
    }
}

// MARK: - Integration

extension RingSmallTests.Integration {

    @Test
    func `interleaved push/pop in inline mode`() {
        var buffer = Buffer<Int>.Ring.Small<4>()
        buffer.push.back(1)
        buffer.push.back(2)
        #expect(buffer.pop.front() == 1)
        buffer.push.back(3)
        #expect(buffer.pop.front() == 2)
        #expect(buffer.pop.front() == 3)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `drain then reuse in inline mode`() {
        var buffer = Buffer<Int>.Ring.Small<4>()
        buffer.push.back(10)
        buffer.push.back(20)
        buffer.drain { _ in }
        #expect(buffer.isEmpty == true)

        buffer.push.back(30)
        #expect(buffer.pop.front() == 30)
    }
}
