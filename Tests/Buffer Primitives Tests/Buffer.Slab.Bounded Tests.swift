import Testing
import Buffer_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Slab.Bounded")
struct SlabBoundedTests {

    @Test("insert and remove at specific slots")
    func insertRemove() {
        var buffer = Buffer.Slab.Bounded<Int>(minimumCapacity: 8)
        let slot: Bit.Index = 3
        buffer.insert(42, at: slot)
        #expect(buffer.isOccupied(at: slot) == true)
        #expect(buffer.occupancy == 1)

        let value = buffer.remove(at: slot)
        #expect(value == 42)
        #expect(!buffer.isOccupied(at: slot) == true)
        #expect(buffer.isEmpty == true)
    }

    @Test("sparse occupancy — non-contiguous slots")
    func sparseOccupancy() {
        var buffer = Buffer.Slab.Bounded<Int>(minimumCapacity: 8)
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 3)
        buffer.insert(30, at: 7)

        #expect(buffer.occupancy == 3)
        #expect(buffer.isOccupied(at: 0) == true)
        #expect(!buffer.isOccupied(at: 1) == true)
        #expect(buffer.isOccupied(at: 3) == true)
        #expect(buffer.isOccupied(at: 7) == true)
    }

    @Test("slot reuse after removal")
    func slotReuse() {
        var buffer = Buffer.Slab.Bounded<Int>(minimumCapacity: 4)
        let slot: Bit.Index = 1
        buffer.insert(10, at: slot)
        _ = buffer.remove(at: slot)
        buffer.insert(20, at: slot)
        #expect(buffer.remove(at: slot) == 20)
    }

    @Test("firstVacant finds available slot")
    func firstVacant() {
        var buffer = Buffer.Slab.Bounded<Int>(minimumCapacity: 4)
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 1)

        let vacant = buffer.firstVacant()
        #expect(vacant == 2)
    }

    @Test("drain removes all elements")
    func drain() {
        var buffer = Buffer.Slab.Bounded<Int>.with([10, 20, 30], capacity: 8)
        var drained: [Int] = []
        buffer.drain { drained.append($0) }
        #expect(buffer.isEmpty == true)
        #expect(drained.sorted() == [10, 20, 30])
    }

    @Test("removeAll clears buffer")
    func removeAll() {
        var buffer = Buffer.Slab.Bounded<Int>.with([1, 2, 3], capacity: 8)
        buffer.removeAll()
        #expect(buffer.isEmpty == true)
        #expect(buffer.occupancy == 0)
    }

    @Test("peek reads without removing (Copyable)")
    func peek() {
        var buffer = Buffer.Slab.Bounded<Int>(minimumCapacity: 8)
        let slot: Bit.Index = 5
        buffer.insert(42, at: slot)
        #expect(buffer.peek(at: slot) == 42)
        #expect(buffer.isOccupied(at: slot) == true)
    }

    @Test("deinit cleans up occupied slots")
    func deinitCleanup() {
        // Create and drop — deinit should iterate bitmap.ones
        var buffer: Buffer.Slab.Bounded<Int>? = Buffer.Slab.Bounded<Int>(
            minimumCapacity: 4
        )
        buffer!.insert(10, at: 0)
        buffer!.insert(20, at: 2)
        buffer = nil
        // No crash = deinit worked correctly
    }
}
