import Testing
import Buffer_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Slab Static Operations")
struct SlabStaticTests {

    @Test("insert and remove")
    func insertRemove() {
        var header: Buffer<Int>.Slab.Header = .init(capacity: 8)
        let storage = Storage<Int>.Heap.create(minimumCapacity: 8)

        let slot: Bit.Index = 3
        Buffer<Int>.Slab.insert(42, at: slot, header: &header, storage: storage)

        #expect(header.isOccupied(at: slot) == true)
        #expect(header.occupancy == 1)

        let value = Buffer<Int>.Slab.remove(at: slot, header: &header, storage: storage)
        #expect(value == 42)
        #expect(!header.isOccupied(at: slot) == true)
        #expect(header.isEmpty == true)

        storage.initialization = .empty
    }

    @Test("forEachOccupied visits all occupied slots")
    func forEachOccupied() {
        var header: Buffer<Int>.Slab.Header = .init(capacity: 8)
        let storage = Storage<Int>.Heap.create(minimumCapacity: 8)

        Buffer<Int>.Slab.insert(10, at: 1, header: &header, storage: storage)
        Buffer<Int>.Slab.insert(30, at: 5, header: &header, storage: storage)

        var visited: [UInt] = []
        Buffer<Int>.Slab.forEachOccupied(header: header, storage: storage) { storageIndex in
            visited.append(storageIndex.rawValue.rawValue)
        }

        #expect(visited.sorted() == [1, 5])

        Buffer<Int>.Slab.deinitializeAll(header: &header, storage: storage)
    }

    @Test("firstVacant finds first empty slot")
    func firstVacant() {
        var header: Buffer<Int>.Slab.Header = .init(capacity: 4)
        header.bitmap[0] = true
        header.bitmap[1] = true

        let vacant = Buffer<Int>.Slab.firstVacant(header: header)
        #expect(vacant == 2)
    }

    @Test("deinitializeAll clears all occupied slots")
    func deinitializeAll() {
        var header: Buffer<Int>.Slab.Header = .init(capacity: 8)
        let storage = Storage<Int>.Heap.create(minimumCapacity: 8)

        Buffer<Int>.Slab.insert(10, at: 0, header: &header, storage: storage)
        Buffer<Int>.Slab.insert(20, at: 3, header: &header, storage: storage)
        Buffer<Int>.Slab.insert(30, at: 7, header: &header, storage: storage)

        Buffer<Int>.Slab.deinitializeAll(header: &header, storage: storage)

        #expect(header.isEmpty == true)
        #expect(header.occupancy == 0)

        storage.initialization = .empty
    }
}
