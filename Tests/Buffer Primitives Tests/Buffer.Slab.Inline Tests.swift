import Testing
import Buffer_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Slab.Inline")
struct SlabBoundedInlineTests {

    @Test
    func `insert and remove at specific slots`() throws {
        var buffer = Buffer<Int>.Slab.Inline<4>()
        let slot: Bit.Index = 2
        buffer.insert(42, at: slot)
        #expect(buffer.isOccupied(at: slot) == true)
        #expect(buffer.occupancy == 1)

        let value = buffer.remove(at: slot)
        #expect(value == 42)
        #expect(!buffer.isOccupied(at: slot) == true)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `sparse occupancy — non-contiguous slots`() throws {
        var buffer = Buffer<Int>.Slab.Inline<4>()
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 2)
        buffer.insert(30, at: 3)

        #expect(buffer.occupancy == 3)
        #expect(buffer.isOccupied(at: 0) == true)
        #expect(!buffer.isOccupied(at: 1) == true)
        #expect(buffer.isOccupied(at: 2) == true)
        #expect(buffer.isOccupied(at: 3) == true)
    }

    @Test
    func `slot reuse after removal`() throws {
        var buffer = Buffer<Int>.Slab.Inline<4>()
        let slot: Bit.Index = 1
        buffer.insert(10, at: slot)
        _ = buffer.remove(at: slot)
        buffer.insert(20, at: slot)
        #expect(buffer.remove(at: slot) == 20)
    }

    @Test
    func `firstVacant finds available slot`() throws {
        var buffer = Buffer<Int>.Slab.Inline<4>()
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 1)

        let vacant = buffer.firstVacant()
        #expect(vacant == 2)
    }

    @Test
    func `firstVacant returns nil when full`() throws {
        var buffer = Buffer<Int>.Slab.Inline<4>()
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 1)
        buffer.insert(30, at: 2)
        buffer.insert(40, at: 3)
        #expect(buffer.isFull == true)

        let vacant = buffer.firstVacant()
        #expect(vacant == nil)
    }

    @Test
    func `drain removes all elements`() throws {
        var buffer = try Buffer<Int>.Slab.Inline<8>([10, 20, 30])
        var drained: [Int] = []
        buffer.drain { drained.append($0) }
        #expect(buffer.isEmpty == true)
        #expect(drained.sorted() == [10, 20, 30])
    }

    @Test
    func `removeAll clears buffer`() throws {
        var buffer = try Buffer<Int>.Slab.Inline<8>([1, 2, 3])
        buffer.removeAll()
        #expect(buffer.isEmpty == true)
        #expect(buffer.occupancy == 0)
    }

    @Test
    func `peek reads without removing (Copyable)`() throws {
        var buffer = Buffer<Int>.Slab.Inline<8>()
        let slot: Bit.Index = 3
        buffer.insert(42, at: slot)
        #expect(buffer.peek(at: slot) == 42)
        #expect(buffer.isOccupied(at: slot) == true)
    }

    @Test
    func `Sequence.Protocol iteration (Copyable)`() throws {
        let buffer = try Buffer<Int>.Slab.Inline<8>([10, 20, 30])
        var collected: [Int] = []
        var iter = buffer.makeIterator()
        while let value = iter.next() {
            collected.append(value)
        }
        #expect(collected == [10, 20, 30])
    }
}
