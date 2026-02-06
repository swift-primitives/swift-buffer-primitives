import Testing
import Buffer_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Slab.Header")
struct SlabHeaderTests {

    @Test
    func `init creates empty bitmap`() {
        let header: Buffer<Int>.Slab.Header = .init(capacity: 8)
        #expect(header.isEmpty == true)
        #expect(!header.isFull == true)
        #expect(header.occupancy == 0)
    }

    @Test
    func `isOccupied tracks bitmap state`() {
        var header: Buffer<Int>.Slab.Header = .init(capacity: 8)
        let slot: Bit.Index = 3
        #expect(!header.isOccupied(at: slot) == true)

        header.bitmap[slot] = true
        #expect(header.isOccupied(at: slot) == true)
    }

    @Test
    func `occupancy reflects popcount`() {
        var header: Buffer<Int>.Slab.Header = .init(capacity: 8)
        header.bitmap[0] = true
        header.bitmap[3] = true
        header.bitmap[7] = true
        #expect(header.occupancy == 3)
    }

    @Test
    func `firstVacant scans for empty slot`() {
        var header: Buffer<Int>.Slab.Header = .init(capacity: 4)
        header.bitmap[0] = true
        header.bitmap[1] = true
        let vacant = header.firstVacant(max: header.bitmap.capacity)
        #expect(vacant == 2)
    }

    @Test
    func `firstVacant returns nil when full`() {
        var header: Buffer<Int>.Slab.Header = .init(capacity: 4)
        header.bitmap[0] = true
        header.bitmap[1] = true
        header.bitmap[2] = true
        header.bitmap[3] = true
        let vacant = header.firstVacant(max: header.bitmap.capacity)
        #expect(vacant == nil)
    }
}
