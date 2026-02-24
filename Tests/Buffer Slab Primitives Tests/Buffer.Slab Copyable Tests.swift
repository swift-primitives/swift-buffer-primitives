import Testing
import Buffer_Slab_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Slab Conditional Copyable")
struct SlabCopyableTests {

    // MARK: - Buffer.Slab

    @Test
    func `Buffer.Slab is Copyable when Element is Copyable`() {
        var original = Buffer<Int>.Slab(minimumCapacity: 8)
        original.insert(10, at: 0)
        original.insert(20, at: 3)
        original.insert(30, at: 7)

        let copy = original
        #expect(copy.occupancy == 3)
        #expect(copy[Bit.Index(Ordinal(0 as UInt))] == 10)
        #expect(copy[Bit.Index(Ordinal(3 as UInt))] == 20)
        #expect(copy[Bit.Index(Ordinal(7 as UInt))] == 30)
    }

    @Test
    func `copied Buffer.Slab is independent of original`() {
        var original = Buffer<Int>.Slab(minimumCapacity: 8)
        original.insert(10, at: 0)
        original.insert(20, at: 3)

        var copy = original

        // Mutate original — copy should be unaffected
        _ = original.remove(at: 0)
        original.insert(99, at: 5)

        #expect(copy.occupancy == 2)
        #expect(copy.isOccupied(at: 0) == true)
        #expect(copy.isOccupied(at: 5) == false)
        #expect(copy[Bit.Index(Ordinal(0 as UInt))] == 10)

        // Mutate copy — original should be unaffected
        copy.insert(77, at: 1)
        #expect(original.isOccupied(at: 1) == false)
    }

    @Test
    func `copied Buffer.Slab deinit does not double-free`() {
        var original: Buffer<Int>.Slab? = Buffer<Int>.Slab(minimumCapacity: 4)
        original!.insert(10, at: 0)
        original!.insert(20, at: 2)

        var copy: Buffer<Int>.Slab? = original
        original = nil
        // Original's Storage.Slab still alive (copy holds reference)
        #expect(copy!.occupancy == 2)

        copy = nil
        // Both dropped — no double-free crash
    }

    @Test
    func `empty Buffer.Slab is Copyable`() {
        let original = Buffer<Int>.Slab(minimumCapacity: 4)
        let copy = original
        #expect(copy.isEmpty == true)
        #expect(copy.occupancy == .zero)
    }

    // MARK: - Buffer.Slab.Bounded

    @Test
    func `Buffer.Slab.Bounded is Copyable when Element is Copyable`() {
        var original = Buffer<Int>.Slab.Bounded(minimumCapacity: 8)
        original.insert(10, at: 0)
        original.insert(20, at: 3)

        let copy = original
        #expect(copy.occupancy == 2)
        #expect(copy.peek(at: 0) == 10)
        #expect(copy.peek(at: 3) == 20)
    }

    @Test
    func `copied Bounded is independent of original`() {
        var original = Buffer<Int>.Slab.Bounded(minimumCapacity: 8)
        original.insert(10, at: 0)
        original.insert(20, at: 1)

        var copy = original

        _ = original.remove(at: 0)
        #expect(copy.occupancy == 2)
        #expect(copy.isOccupied(at: 0) == true)

        copy.insert(77, at: 5)
        #expect(original.isOccupied(at: 5) == false)
    }

    // MARK: - Bitmap Sync

    @Test
    func `bitmap stays synced after insert-remove cycle`() {
        var buffer = Buffer<Int>.Slab(minimumCapacity: 8)
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 1)
        buffer.insert(30, at: 2)
        _ = buffer.remove(at: 1)

        // Copy after mutations — bitmap sync must be correct
        let copy = buffer
        #expect(copy.occupancy == 2)
        #expect(copy.isOccupied(at: 0) == true)
        #expect(copy.isOccupied(at: 1) == false)
        #expect(copy.isOccupied(at: 2) == true)
    }

    @Test
    func `bitmap stays synced after removeAll`() {
        var buffer = Buffer<Int>.Slab(minimumCapacity: 8)
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 3)
        buffer.removeAll()

        let copy = buffer
        #expect(copy.isEmpty == true)
        #expect(copy.occupancy == .zero)
    }

    @Test
    func `bitmap stays synced after drain`() {
        var buffer = Buffer<Int>.Slab(minimumCapacity: 8)
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 3)
        buffer.drain { _ in }

        let copy = buffer
        #expect(copy.isEmpty == true)
    }

    @Test
    func `copy after update preserves values`() {
        var buffer = Buffer<Int>.Slab(minimumCapacity: 8)
        buffer.insert(10, at: 0)
        _ = buffer.update(at: 0, with: 99)

        let copy = buffer
        #expect(copy[Bit.Index(Ordinal(0 as UInt))] == 99)
    }

    // MARK: - Reference Semantics (Shared Storage)

    @Test
    func `copy shares Storage.Slab reference`() {
        var original = Buffer<Int>.Slab(minimumCapacity: 8)
        original.insert(42, at: 0)

        // Copy shares the Storage.Slab reference (class)
        // Both see the same underlying heap
        let copy = original

        // Both can read the same element
        #expect(original[Bit.Index(Ordinal(0 as UInt))] == 42)
        #expect(copy[Bit.Index(Ordinal(0 as UInt))] == 42)
    }
}
