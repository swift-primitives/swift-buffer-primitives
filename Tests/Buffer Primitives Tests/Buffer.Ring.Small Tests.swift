import Testing
import Buffer_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Ring.Small")
struct RingSmallTests {

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
        buffer.pushBack(10)
        buffer.pushBack(20)
        buffer.pushBack(30)

        #expect(buffer.count == 3)
        #expect(buffer.isSpilled == false)
    }

    @Test
    func `spill to heap when inline is full`() {
        var buffer = Buffer<Int>.Ring.Small<2>()
        buffer.pushBack(10)
        buffer.pushBack(20)
        #expect(buffer.isSpilled == false)

        buffer.pushBack(30)
        #expect(buffer.isSpilled == true)
        #expect(buffer.count == 3)
    }

    @Test
    func `elements survive spill — FIFO order preserved`() {
        var buffer = Buffer<Int>.Ring.Small<2>()
        buffer.pushBack(10)
        buffer.pushBack(20)
        #expect(buffer.isSpilled == false)

        buffer.pushBack(30)
        #expect(buffer.isSpilled == true)

        #expect(buffer.popFront() == 10)
        #expect(buffer.popFront() == 20)
        #expect(buffer.popFront() == 30)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `pushBack and popFront after spill`() {
        var buffer = Buffer<Int>.Ring.Small<2>()
        buffer.pushBack(10)
        buffer.pushBack(20)
        buffer.pushBack(30) // triggers spill
        #expect(buffer.isSpilled == true)

        buffer.pushBack(40)
        buffer.pushBack(50)

        #expect(buffer.popFront() == 10)
        #expect(buffer.popFront() == 20)
        #expect(buffer.popFront() == 30)
        #expect(buffer.popFront() == 40)
        #expect(buffer.popFront() == 50)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `pushFront and popBack after spill`() {
        var buffer = Buffer<Int>.Ring.Small<2>()
        buffer.pushBack(10)
        buffer.pushBack(20)
        buffer.pushBack(30) // triggers spill
        #expect(buffer.isSpilled == true)

        buffer.pushFront(5)
        #expect(buffer.popBack() == 30)
        #expect(buffer.popBack() == 20)
        #expect(buffer.popBack() == 10)
        #expect(buffer.popBack() == 5)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `removeAll resets to inline mode`() {
        var buffer = Buffer<Int>.Ring.Small<2>()
        buffer.pushBack(10)
        buffer.pushBack(20)
        buffer.pushBack(30)
        #expect(buffer.isSpilled == true)

        buffer.removeAll()
        #expect(buffer.isEmpty == true)
        #expect(buffer.isSpilled == false)
    }

    @Test
    func `removeAll keepingCapacity stays in heap mode`() {
        var buffer = Buffer<Int>.Ring.Small<2>()
        buffer.pushBack(10)
        buffer.pushBack(20)
        buffer.pushBack(30)
        #expect(buffer.isSpilled == true)

        buffer.removeAll(keepingCapacity: true)
        #expect(buffer.isEmpty == true)
        #expect(buffer.isSpilled == true)
    }

    @Test
    func `double-ended operations in inline mode`() {
        var buffer = Buffer<Int>.Ring.Small<4>()
        buffer.pushFront(10)
        buffer.pushBack(20)
        buffer.pushFront(5)
        buffer.pushBack(25)

        // Order: 5, 10, 20, 25
        #expect(buffer.peekFront == 5)
        #expect(buffer.peekBack == 25)
        #expect(buffer.popFront() == 5)
        #expect(buffer.popBack() == 25)
        #expect(buffer.popFront() == 10)
        #expect(buffer.popBack() == 20)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `double-ended operations in heap mode`() {
        var buffer = Buffer<Int>.Ring.Small<2>()
        buffer.pushBack(10)
        buffer.pushBack(20)
        buffer.pushBack(30) // triggers spill

        buffer.pushFront(5)
        buffer.pushBack(35)

        // Order: 5, 10, 20, 30, 35
        #expect(buffer.peekFront == 5)
        #expect(buffer.peekBack == 35)
        #expect(buffer.popFront() == 5)
        #expect(buffer.popBack() == 35)
        #expect(buffer.count == 3)
    }

    @Test
    func `ensureUnique in heap mode`() {
        var buffer = Buffer<Int>.Ring.Small<2>()
        buffer.pushBack(10)
        buffer.pushBack(20)
        buffer.pushBack(30)
        #expect(buffer.isSpilled == true)

        // Ring.Small.ensureUnique unconditionally copies in heap mode
        let didCopy = buffer.ensureUnique()
        #expect(didCopy == true)
    }

    @Test
    func `ensureUnique in inline mode returns false`() {
        var buffer = Buffer<Int>.Ring.Small<4>()
        buffer.pushBack(10)

        let didCopy = buffer.ensureUnique()
        #expect(didCopy == false)
    }

    @Test
    func `peekFront and peekBack in inline mode`() {
        var buffer = Buffer<Int>.Ring.Small<4>()
        buffer.pushBack(10)
        buffer.pushBack(20)
        buffer.pushBack(30)

        #expect(buffer.peekFront == 10)
        #expect(buffer.peekBack == 30)
        #expect(buffer.count == 3)
    }

    @Test
    func `drain removes all in FIFO order`() {
        var buffer = Buffer<Int>.Ring.Small<4>()
        buffer.pushBack(10)
        buffer.pushBack(20)
        buffer.pushBack(30)

        var drained: [Int] = []
        buffer.drain { drained.append($0) }
        #expect(drained == [10, 20, 30])
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `interleaved push/pop in inline mode`() {
        var buffer = Buffer<Int>.Ring.Small<4>()
        buffer.pushBack(1)
        buffer.pushBack(2)
        #expect(buffer.popFront() == 1)
        buffer.pushBack(3)
        #expect(buffer.popFront() == 2)
        #expect(buffer.popFront() == 3)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `wrap-around in inline mode`() {
        var buffer = Buffer<Int>.Ring.Small<4>()
        buffer.pushBack(0)
        buffer.pushBack(1)
        buffer.pushBack(2)
        buffer.pushBack(3)
        #expect(buffer.isFull == true)

        _ = buffer.popFront()
        _ = buffer.popFront()
        buffer.pushBack(100)
        buffer.pushBack(200)

        #expect(buffer.popFront() == 2)
        #expect(buffer.popFront() == 3)
        #expect(buffer.popFront() == 100)
        #expect(buffer.popFront() == 200)
        #expect(buffer.isEmpty == true)
    }
}
