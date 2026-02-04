import Testing
import Buffer_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Slab.Header")
struct SlabHeaderTests {

    @Test("init creates empty bitmap")
    func initDefaults() {
        let header: Buffer.Slab<Int>.Header = .init(capacity: 8)
        #expect(header.isEmpty == true)
        #expect(!header.isFull == true)
        #expect(header.occupancy == 0)
    }

    @Test("isOccupied tracks bitmap state")
    func isOccupied() {
        var header: Buffer.Slab<Int>.Header = .init(capacity: 8)
        let slot: Bit.Index = 3
        #expect(!header.isOccupied(at: slot) == true)

        header.bitmap[slot] = true
        #expect(header.isOccupied(at: slot) == true)
    }

    @Test("occupancy reflects popcount")
    func occupancyPopcount() {
        var header: Buffer.Slab<Int>.Header = .init(capacity: 8)
        header.bitmap[0] = true
        header.bitmap[3] = true
        header.bitmap[7] = true
        #expect(header.occupancy == 3)
    }

    @Test("firstVacant scans for empty slot")
    func firstVacant() {
        var header: Buffer.Slab<Int>.Header = .init(capacity: 4)
        header.bitmap[0] = true
        header.bitmap[1] = true
        let vacant = header.firstVacant(max: header.bitmap.capacity)
        #expect(vacant == 2)
    }

    @Test("firstVacant returns nil when full")
    func firstVacantFull() {
        var header: Buffer.Slab<Int>.Header = .init(capacity: 4)
        header.bitmap[0] = true
        header.bitmap[1] = true
        header.bitmap[2] = true
        header.bitmap[3] = true
        let vacant = header.firstVacant(max: header.bitmap.capacity)
        #expect(vacant == nil)
    }
}
