import Testing
import Buffer_Linear_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Linear clone")
struct LinearCloneTests {

    @Test
    func `clone produces independent storage`() {
        var original: Buffer<Int>.Linear = [1, 2, 3]
        let cloned = original.clone()

        original.append(999)

        #expect(original.count == 4)
        #expect(cloned.count == 3)
    }

    @Test
    func `clone sizes capacity to count`() {
        var source: Buffer<Int>.Linear = []
        source.reserveCapacity(100)
        source.append(1)
        source.append(2)

        let cloned = source.clone()

        #expect(cloned.count == 2)
        #expect(cloned.capacity >= 2)
        // The cloned buffer's capacity should be near the count, not 100.
        // (Storage may round up to slotCapacity, so exact equality isn't asserted.)
        #expect(cloned.capacity < source.capacity)
    }

    @Test
    func `clone of empty buffer`() {
        let source = Buffer<Int>.Linear(minimumCapacity: 0)
        let cloned = source.clone()
        #expect(cloned.isEmpty)
    }

    @Test
    func `clone with explicit capacity`() {
        var source: Buffer<Int>.Linear = [10, 20, 30]
        let cloned = source.clone(capacity: 50)

        #expect(cloned.count == 3)
        #expect(cloned.capacity >= 50)

        source.append(999)  // Should not affect cloned
        #expect(cloned.count == 3)
    }
}
