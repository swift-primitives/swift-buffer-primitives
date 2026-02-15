import Testing
import Buffer_Slab_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Slab")
struct SlabGrowableTests {

    @Test
    func `init creates empty growable slab`() {
        let buffer = Buffer<Int>.Slab(minimumCapacity: 8)
        #expect(buffer.isEmpty == true)
        #expect(buffer.occupancy == .zero)
        #expect(buffer.isFull == false)
    }

    @Test
    func `insert and remove at specific slots`() {
        var buffer = Buffer<Int>.Slab(minimumCapacity: 8)
        let slot: Bit.Index = 3
        buffer.insert(42, at: slot)
        #expect(buffer.occupancy == 1)

        let value = buffer.remove(at: slot)
        #expect(value == 42)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `sparse occupancy — non-contiguous slots`() {
        var buffer = Buffer<Int>.Slab(minimumCapacity: 8)
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 3)
        buffer.insert(30, at: 7)

        #expect(buffer.occupancy == 3)
    }

    @Test
    func `firstVacant returns correct slot`() {
        var buffer = Buffer<Int>.Slab(minimumCapacity: 4)
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 1)

        let vacant = buffer.firstVacant()
        #expect(vacant == 2)
    }

    @Test
    func `slot reuse after removal`() {
        var buffer = Buffer<Int>.Slab(minimumCapacity: 4)
        let slot: Bit.Index = 1
        buffer.insert(10, at: slot)
        _ = buffer.remove(at: slot)
        buffer.insert(20, at: slot)
        #expect(buffer.remove(at: slot) == 20)
    }

    @Test
    func `multiple insert and remove`() {
        var buffer = Buffer<Int>.Slab(minimumCapacity: 8)
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 1)
        buffer.insert(30, at: 2)
        #expect(buffer.occupancy == 3)

        let v1 = buffer.remove(at: 1)
        #expect(v1 == 20)
        #expect(buffer.occupancy == 2)

        buffer.insert(40, at: 1)
        #expect(buffer.occupancy == 3)
        #expect(buffer.remove(at: 1) == 40)
    }

    @Test
    func `update replaces element`() {
        var buffer = Buffer<Int>.Slab(minimumCapacity: 8)
        buffer.insert(10, at: 0)

        let old = buffer.update(at: 0, with: 99)
        #expect(old == 10)
        #expect(buffer.remove(at: 0) == 99)
    }

    @Test
    func `drain removes all elements`() {
        var buffer = Buffer<Int>.Slab(minimumCapacity: 8)
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 3)
        buffer.insert(30, at: 7)

        var drained: [Int] = []
        buffer.drain { drained.append($0) }
        #expect(buffer.isEmpty == true)
        #expect(drained.sorted() == [10, 20, 30])
    }

    @Test
    func `removeAll clears buffer`() {
        var buffer = Buffer<Int>.Slab(minimumCapacity: 8)
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 1)
        buffer.insert(30, at: 2)
        buffer.removeAll()

        #expect(buffer.isEmpty == true)
        #expect(buffer.occupancy == .zero)
    }

    @Test
    func `deinit cleans up occupied slots`() {
        var buffer: Buffer<Int>.Slab? = Buffer<Int>.Slab(minimumCapacity: 4)
        buffer!.insert(10, at: 0)
        buffer!.insert(20, at: 2)
        buffer = nil
        // No crash = deinit worked correctly
    }
}
