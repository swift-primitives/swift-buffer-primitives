import Testing
import Buffer_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Linked.Small")
struct LinkedSmallTests {

    @Test
    func `starts in inline mode`() {
        let buffer = Buffer<Int>.Linked<2>.Small<4>()
        #expect(buffer.isEmpty == true)
        #expect(buffer.count == .zero)
        #expect(buffer.isSpilled == false)
    }

    @Test
    func `insertBack within inline capacity stays inline`() {
        var buffer = Buffer<Int>.Linked<2>.Small<4>()
        buffer.insertBack(10)
        buffer.insertBack(20)
        buffer.insertBack(30)

        #expect(buffer.count == 3)
        #expect(buffer.isSpilled == false)
    }

    @Test
    func `insertFront within inline capacity stays inline`() {
        var buffer = Buffer<Int>.Linked<2>.Small<4>()
        buffer.insertFront(10)
        buffer.insertFront(20)
        buffer.insertFront(30)

        #expect(buffer.count == 3)
        #expect(buffer.isSpilled == false)
    }

    @Test
    func `spill to heap when inline is full`() {
        var buffer = Buffer<Int>.Linked<2>.Small<2>()
        buffer.insertBack(10)
        buffer.insertBack(20)
        #expect(buffer.isSpilled == false)

        // This should trigger spill
        buffer.insertBack(30)
        #expect(buffer.isSpilled == true)
        #expect(buffer.count == 3)
    }

    @Test
    func `elements survive spill`() {
        var buffer = Buffer<Int>.Linked<2>.Small<2>()
        buffer.insertBack(10)
        buffer.insertBack(20)
        #expect(buffer.isSpilled == false)

        buffer.insertBack(30)
        #expect(buffer.isSpilled == true)

        // Verify all elements survived in order
        var collected: [Int] = []
        buffer.forEach { collected.append($0) }
        #expect(collected == [10, 20, 30])
    }

    @Test
    func `removeFront in inline mode`() {
        var buffer = Buffer<Int>.Linked<2>.Small<4>()
        buffer.insertBack(10)
        buffer.insertBack(20)
        buffer.insertBack(30)

        #expect(buffer.removeFront() == 10)
        #expect(buffer.removeFront() == 20)
        #expect(buffer.removeFront() == 30)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `removeFront in heap mode`() {
        var buffer = Buffer<Int>.Linked<2>.Small<2>()
        buffer.insertBack(10)
        buffer.insertBack(20)
        buffer.insertBack(30)
        #expect(buffer.isSpilled == true)

        #expect(buffer.removeFront() == 10)
        #expect(buffer.removeFront() == 20)
        #expect(buffer.removeFront() == 30)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `removeBack in inline mode`() {
        var buffer = Buffer<Int>.Linked<2>.Small<4>()
        buffer.insertBack(10)
        buffer.insertBack(20)
        buffer.insertBack(30)

        #expect(buffer.removeBack() == 30)
        #expect(buffer.removeBack() == 20)
        #expect(buffer.removeBack() == 10)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `removeBack in heap mode`() {
        var buffer = Buffer<Int>.Linked<2>.Small<2>()
        buffer.insertBack(10)
        buffer.insertBack(20)
        buffer.insertBack(30)
        #expect(buffer.isSpilled == true)

        #expect(buffer.removeBack() == 30)
        #expect(buffer.removeBack() == 20)
        #expect(buffer.removeBack() == 10)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `operations after spill`() {
        var buffer = Buffer<Int>.Linked<2>.Small<2>()
        buffer.insertBack(10)
        buffer.insertBack(20)
        buffer.insertBack(30)
        #expect(buffer.isSpilled == true)

        // Continued inserts in heap mode
        buffer.insertBack(40)
        buffer.insertFront(5)
        #expect(buffer.count == 5)

        var collected: [Int] = []
        buffer.forEach { collected.append($0) }
        #expect(collected == [5, 10, 20, 30, 40])
    }

    @Test
    func `first and last in inline mode`() {
        var buffer = Buffer<Int>.Linked<2>.Small<4>()
        #expect(buffer.first == nil)
        #expect(buffer.last == nil)

        buffer.insertBack(10)
        buffer.insertBack(20)
        buffer.insertBack(30)

        #expect(buffer.first == 10)
        #expect(buffer.last == 30)
    }

    @Test
    func `first and last in heap mode`() {
        var buffer = Buffer<Int>.Linked<2>.Small<2>()
        buffer.insertBack(10)
        buffer.insertBack(20)
        buffer.insertBack(30)
        #expect(buffer.isSpilled == true)

        #expect(buffer.first == 10)
        #expect(buffer.last == 30)
    }

    @Test
    func `removeAll resets to inline mode`() {
        var buffer = Buffer<Int>.Linked<2>.Small<2>()
        buffer.insertBack(10)
        buffer.insertBack(20)
        buffer.insertBack(30)
        #expect(buffer.isSpilled == true)

        buffer.removeAll()
        #expect(buffer.isEmpty == true)
        #expect(buffer.isSpilled == false)
    }

    @Test
    func `removeAll keepingCapacity true stays in heap mode`() {
        var buffer = Buffer<Int>.Linked<2>.Small<2>()
        buffer.insertBack(10)
        buffer.insertBack(20)
        buffer.insertBack(30)
        #expect(buffer.isSpilled == true)

        buffer.removeAll(keepingCapacity: true)
        #expect(buffer.isEmpty == true)
        #expect(buffer.isSpilled == true)
    }

    @Test
    func `removeAll keepingCapacity false resets to inline`() {
        var buffer = Buffer<Int>.Linked<2>.Small<2>()
        buffer.insertBack(10)
        buffer.insertBack(20)
        buffer.insertBack(30)
        #expect(buffer.isSpilled == true)

        buffer.removeAll(keepingCapacity: false)
        #expect(buffer.isEmpty == true)
        #expect(buffer.isSpilled == false)
    }

    @Test
    func `forEach in inline mode`() {
        var buffer = Buffer<Int>.Linked<2>.Small<4>()
        buffer.insertBack(10)
        buffer.insertBack(20)
        buffer.insertBack(30)

        var collected: [Int] = []
        buffer.forEach { collected.append($0) }
        #expect(collected == [10, 20, 30])
    }

    @Test
    func `forEach in heap mode`() {
        var buffer = Buffer<Int>.Linked<2>.Small<2>()
        buffer.insertBack(10)
        buffer.insertBack(20)
        buffer.insertBack(30)
        #expect(buffer.isSpilled == true)

        var collected: [Int] = []
        buffer.forEach { collected.append($0) }
        #expect(collected == [10, 20, 30])
    }

    @Test
    func `forEachReversed in inline mode`() {
        var buffer = Buffer<Int>.Linked<2>.Small<4>()
        buffer.insertBack(10)
        buffer.insertBack(20)
        buffer.insertBack(30)

        var collected: [Int] = []
        buffer.forEachReversed { collected.append($0) }
        #expect(collected == [30, 20, 10])
    }

    @Test
    func `forEachReversed in heap mode`() {
        var buffer = Buffer<Int>.Linked<2>.Small<2>()
        buffer.insertBack(10)
        buffer.insertBack(20)
        buffer.insertBack(30)
        #expect(buffer.isSpilled == true)

        var collected: [Int] = []
        buffer.forEachReversed { collected.append($0) }
        #expect(collected == [30, 20, 10])
    }

    @Test
    func `empty buffer operations`() {
        var buffer = Buffer<Int>.Linked<2>.Small<4>()
        #expect(buffer.isEmpty == true)
        #expect(buffer.removeFront() == nil)
        #expect(buffer.removeBack() == nil)
    }

    @Test
    func `single element inline`() {
        var buffer = Buffer<Int>.Linked<2>.Small<4>()
        buffer.insertBack(42)
        #expect(buffer.count == 1)
        #expect(buffer.isSpilled == false)
        #expect(buffer.first == 42)
        #expect(buffer.last == 42)
        #expect(buffer.removeFront() == 42)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `ensureUnique in heap mode`() {
        var buffer = Buffer<Int>.Linked<2>.Small<2>()
        buffer.insertBack(10)
        buffer.insertBack(20)
        buffer.insertBack(30)
        #expect(buffer.isSpilled == true)

        // In heap mode, ensureUnique should work
        let didCopy = buffer.ensureUnique()
        // First call on sole reference should not copy
        #expect(didCopy == false)
    }

    @Test
    func `ensureUnique in inline mode returns false`() {
        var buffer = Buffer<Int>.Linked<2>.Small<4>()
        buffer.insertBack(10)
        #expect(buffer.isSpilled == false)

        // In inline mode, ensureUnique is a no-op
        let didCopy = buffer.ensureUnique()
        #expect(didCopy == false)
    }

    @Test
    func `isFull in inline mode`() {
        var buffer = Buffer<Int>.Linked<2>.Small<2>()
        #expect(buffer.isFull == false)
        buffer.insertBack(1)
        #expect(buffer.isFull == false)
        buffer.insertBack(2)
        #expect(buffer.isFull == true)
    }

    @Test
    func `capacity reflects mode`() {
        var buffer = Buffer<Int>.Linked<2>.Small<4>()
        #expect(buffer.capacity == Index<Int>.Count(UInt(4)))

        buffer.insertBack(1)
        buffer.insertBack(2)
        buffer.insertBack(3)
        buffer.insertBack(4)
        buffer.insertBack(5) // triggers spill
        #expect(buffer.isSpilled == true)
        #expect(buffer.capacity.rawValue.rawValue >= 8)
    }
}
