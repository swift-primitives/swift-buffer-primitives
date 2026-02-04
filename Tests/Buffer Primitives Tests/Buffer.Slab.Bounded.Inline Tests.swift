import Testing
import Buffer_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Slab.Bounded.Inline")
struct SlabBoundedInlineTests {

    @Test("insert and remove at specific slots")
    func insertRemove() throws {
        var buffer = try Buffer.Slab.Bounded<Int>.Inline<4>()
        let slot: Bit.Index = 2
        buffer.insert(42, at: slot)
        #expect(buffer.isOccupied(at: slot) == true)
        #expect(buffer.occupancy == 1)

        let value = buffer.remove(at: slot)
        #expect(value == 42)
        #expect(!buffer.isOccupied(at: slot) == true)
        #expect(buffer.isEmpty == true)
    }

    @Test("sparse occupancy — non-contiguous slots")
    func sparseOccupancy() throws {
        var buffer = try Buffer.Slab.Bounded<Int>.Inline<4>()
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 2)
        buffer.insert(30, at: 3)

        #expect(buffer.occupancy == 3)
        #expect(buffer.isOccupied(at: 0) == true)
        #expect(!buffer.isOccupied(at: 1) == true)
        #expect(buffer.isOccupied(at: 2) == true)
        #expect(buffer.isOccupied(at: 3) == true)
    }

    @Test("slot reuse after removal")
    func slotReuse() throws {
        var buffer = try Buffer.Slab.Bounded<Int>.Inline<4>()
        let slot: Bit.Index = 1
        buffer.insert(10, at: slot)
        _ = buffer.remove(at: slot)
        buffer.insert(20, at: slot)
        #expect(buffer.remove(at: slot) == 20)
    }

    @Test("firstVacant finds available slot")
    func firstVacant() throws {
        var buffer = try Buffer.Slab.Bounded<Int>.Inline<4>()
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 1)

        let vacant = buffer.firstVacant()
        #expect(vacant == 2)
    }

    @Test("firstVacant returns nil when full")
    func firstVacantWhenFull() throws {
        var buffer = try Buffer.Slab.Bounded<Int>.Inline<4>()
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 1)
        buffer.insert(30, at: 2)
        buffer.insert(40, at: 3)
        #expect(buffer.isFull)

        let vacant = buffer.firstVacant()
        #expect(vacant == nil)
    }

    @Test("drain removes all elements")
    func drain() throws {
        var buffer = try Buffer.Slab.Bounded<Int>.Inline<8>.with([10, 20, 30])
        var drained: [Int] = []
        buffer.drain { drained.append($0) }
        #expect(buffer.isEmpty == true)
        #expect(drained.sorted() == [10, 20, 30])
    }

    @Test("removeAll clears buffer")
    func removeAll() throws {
        var buffer = try Buffer.Slab.Bounded<Int>.Inline<8>.with([1, 2, 3])
        buffer.removeAll()
        #expect(buffer.isEmpty == true)
        #expect(buffer.occupancy == 0)
    }

    @Test("peek reads without removing (Copyable)")
    func peek() throws {
        var buffer = try Buffer.Slab.Bounded<Int>.Inline<8>()
        let slot: Bit.Index = 3
        buffer.insert(42, at: slot)
        #expect(buffer.peek(at: slot) == 42)
        #expect(buffer.isOccupied(at: slot) == true)
    }

    @Test("Sequence.Protocol iteration (Copyable)")
    func sequenceIteration() throws {
        let buffer = try Buffer.Slab.Bounded<Int>.Inline<8>.with([10, 20, 30])
        var collected: [Int] = []
        var iter = buffer.makeIterator()
        while let value = iter.next() {
            collected.append(value)
        }
        #expect(collected == [10, 20, 30])
    }
}
