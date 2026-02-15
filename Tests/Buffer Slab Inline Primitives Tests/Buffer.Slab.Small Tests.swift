import Testing
import Buffer_Slab_Inline_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Slab.Small")
struct SlabSmallTests {

    @Test
    func `init creates empty inline slab`() {
        let buffer = Buffer<Int>.Slab.Small<4>()
        #expect(buffer.isEmpty == true)
        #expect(buffer.occupancy == .zero)
        #expect(buffer.isFull == false)
        #expect(buffer.isSpilled == false)
    }

    @Test
    func `insert and remove in inline mode`() {
        var buffer = Buffer<Int>.Slab.Small<4>()
        buffer.insert(42, at: 0)
        #expect(buffer.occupancy == 1)
        #expect(buffer.isSpilled == false)

        let value = buffer.remove(at: 0)
        #expect(value == 42)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `sparse occupancy in inline mode`() {
        var buffer = Buffer<Int>.Slab.Small<4>()
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 2)
        #expect(buffer.occupancy == 2)
        #expect(buffer.isOccupied(at: 0) == true)
        #expect(buffer.isOccupied(at: 1) == false)
        #expect(buffer.isOccupied(at: 2) == true)
    }

    @Test
    func `spill to heap when inline is full`() {
        var buffer = Buffer<Int>.Slab.Small<2>()
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 1)
        #expect(buffer.isFull == true)
        #expect(buffer.isSpilled == false)

        // Third insert triggers spill
        buffer.insert(30, at: 2)
        #expect(buffer.isSpilled == true)
        #expect(buffer.occupancy == 3)
    }

    @Test
    func `elements preserved after spill`() {
        var buffer = Buffer<Int>.Slab.Small<2>()
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 1)
        buffer.insert(30, at: 2)

        #expect(buffer.isSpilled == true)
        #expect(buffer.peek(at: 0) == 10)
        #expect(buffer.peek(at: 1) == 20)
        #expect(buffer.peek(at: 2) == 30)
    }

    @Test
    func `remove in heap mode`() {
        var buffer = Buffer<Int>.Slab.Small<2>()
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 1)
        buffer.insert(30, at: 2)

        let value = buffer.remove(at: 1)
        #expect(value == 20)
        #expect(buffer.occupancy == 2)
        #expect(buffer.isOccupied(at: 1) == false)
    }

    @Test
    func `update in inline mode`() {
        var buffer = Buffer<Int>.Slab.Small<4>()
        buffer.insert(10, at: 0)

        let old = buffer.update(at: 0, with: 99)
        #expect(old == 10)
        #expect(buffer.peek(at: 0) == 99)
    }

    @Test
    func `update in heap mode`() {
        var buffer = Buffer<Int>.Slab.Small<2>()
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 1)
        buffer.insert(30, at: 2)

        let old = buffer.update(at: 2, with: 99)
        #expect(old == 30)
        #expect(buffer.peek(at: 2) == 99)
    }

    @Test
    func `firstVacant in inline mode`() {
        var buffer = Buffer<Int>.Slab.Small<4>()
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 1)

        let vacant = buffer.firstVacant()
        #expect(vacant == 2)
    }

    @Test
    func `firstVacant in heap mode`() {
        var buffer = Buffer<Int>.Slab.Small<2>()
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 1)
        buffer.insert(30, at: 2)
        _ = buffer.remove(at: 1)

        let vacant = buffer.firstVacant()
        #expect(vacant == 1)
    }

    @Test
    func `removeAll resets to inline mode`() {
        var buffer = Buffer<Int>.Slab.Small<2>()
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 1)
        buffer.insert(30, at: 2)
        #expect(buffer.isSpilled == true)

        buffer.removeAll()
        #expect(buffer.isEmpty == true)
        #expect(buffer.isSpilled == false)
    }

    @Test
    func `removeAll in inline mode`() {
        var buffer = Buffer<Int>.Slab.Small<4>()
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 2)
        buffer.removeAll()

        #expect(buffer.isEmpty == true)
        #expect(buffer.isSpilled == false)
    }

    @Test
    func `drain removes all elements`() {
        var buffer = Buffer<Int>.Slab.Small<2>()
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 1)
        buffer.insert(30, at: 2)

        var drained: [Int] = []
        buffer.drain { drained.append($0) }
        #expect(buffer.isEmpty == true)
        #expect(drained.sorted() == [10, 20, 30])
    }

    @Test
    func `drain in inline mode`() {
        var buffer = Buffer<Int>.Slab.Small<4>()
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 3)

        var drained: [Int] = []
        buffer.drain { drained.append($0) }
        #expect(buffer.isEmpty == true)
        #expect(drained.sorted() == [10, 20])
    }

    @Test
    func `peek reads without removing`() {
        var buffer = Buffer<Int>.Slab.Small<4>()
        buffer.insert(42, at: 1)

        #expect(buffer.peek(at: 1) == 42)
        #expect(buffer.occupancy == 1)
    }

    @Test
    func `slot reuse after removal`() {
        var buffer = Buffer<Int>.Slab.Small<4>()
        buffer.insert(10, at: 1)
        _ = buffer.remove(at: 1)
        buffer.insert(20, at: 1)
        #expect(buffer.remove(at: 1) == 20)
    }

    @Test
    func `deinit cleans up inline mode`() {
        var buffer: Buffer<Int>.Slab.Small<4>? = Buffer<Int>.Slab.Small<4>()
        buffer!.insert(10, at: 0)
        buffer!.insert(20, at: 2)
        buffer = nil
        // No crash = deinit worked correctly
    }

    @Test
    func `deinit cleans up heap mode`() {
        var buffer: Buffer<Int>.Slab.Small<2>? = Buffer<Int>.Slab.Small<2>()
        buffer!.insert(10, at: 0)
        buffer!.insert(20, at: 1)
        buffer!.insert(30, at: 2)
        buffer = nil
        // No crash = deinit worked correctly
    }
}
