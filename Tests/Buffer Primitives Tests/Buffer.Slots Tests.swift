import Testing
import Buffer_Primitives
import Buffer_Primitives_Test_Support

// Buffer.Slots is generic (Buffer<Element>.Slots<Metadata>), so per [TEST-004]
// we use the parallel namespace pattern — @Suite in extensions of generic type
// specializations is silently not discovered by Swift Testing.

@Suite("Buffer.Slots")
struct SlotsTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
}

// MARK: - Unit

extension SlotsTests.Unit {

    @Test
    func `init creates buffer with requested capacity`() {
        let capacity: Index<Int>.Count = 8
        let buffer = Buffer<Int>.Slots<UInt8>(capacity: capacity, metadataInitial: 0x80)
        #expect(buffer.capacity == capacity)
    }

    @Test
    func `metadata subscript reads initial value`() {
        let buffer = Buffer<Int>.Slots<UInt8>(capacity: 4, metadataInitial: 0x80)
        let slot: Index<Int> = 0
        #expect(buffer[metadata: slot] == 0x80)
    }

    @Test
    func `metadata subscript writes and reads back`() {
        var buffer = Buffer<Int>.Slots<UInt8>(capacity: 4, metadataInitial: 0x80)
        let slot: Index<Int> = 2
        buffer[metadata: slot] = 0x42
        #expect(buffer[metadata: slot] == 0x42)
    }

    @Test
    func `initialize and move round-trips element`() {
        let buffer = Buffer<Int>.Slots<UInt8>(capacity: 4, metadataInitial: 0x80)
        let slot: Index<Int> = 1
        buffer.initialize(to: 99, at: slot)
        let value = buffer.move(at: slot)
        #expect(value == 99)
    }

    @Test
    func `initialize and deinitialize does not crash`() {
        let buffer = Buffer<Int>.Slots<UInt8>(capacity: 4, metadataInitial: 0x80)
        let slot: Index<Int> = 0
        buffer.initialize(to: 42, at: slot)
        buffer.deinitialize(at: slot)
    }

    @Test
    func `payload subscript reads initialized element`() {
        let buffer = Buffer<Int>.Slots<UInt8>(capacity: 4, metadataInitial: 0x80)
        let slot: Index<Int> = 2
        buffer.initialize(to: 77, at: slot)
        #expect(buffer[payload: slot] == 77)
        buffer.deinitialize(at: slot)
    }

    @Test
    func `payload subscript overwrites element`() {
        var buffer = Buffer<Int>.Slots<UInt8>(capacity: 4, metadataInitial: 0x80)
        let slot: Index<Int> = 1
        buffer.initialize(to: 10, at: slot)
        buffer[payload: slot] = 20
        #expect(buffer[payload: slot] == 20)
        buffer.deinitialize(at: slot)
    }

    @Test
    func `fill metadata overwrites all slots`() {
        var buffer = Buffer<Int>.Slots<UInt8>(capacity: 4, metadataInitial: 0x80)
        buffer[metadata: 0] = 0x42
        buffer[metadata: 1] = 0x43
        buffer.fill(metadata: 0xFF)
        #expect(buffer[metadata: 0] == 0xFF)
        #expect(buffer[metadata: 1] == 0xFF)
        #expect(buffer[metadata: 2] == 0xFF)
        #expect(buffer[metadata: 3] == 0xFF)
    }

    @Test
    func `fill payload writes all slots`() {
        let buffer = Buffer<Int>.Slots<UInt8>(capacity: 4, metadataInitial: 0x80)
        buffer.fill(payload: 0)
        #expect(buffer[payload: 0] == 0)
        #expect(buffer[payload: 1] == 0)
        #expect(buffer[payload: 2] == 0)
        #expect(buffer[payload: 3] == 0)
        // Clean up — all slots are initialized via fill
        buffer.deinitialize(where: { _ in true })
    }

    @Test
    func `deinitialize where cleans up occupied slots`() {
        var buffer = Buffer<Int>.Slots<UInt8>(capacity: 4, metadataInitial: 0x80)
        // Simulate Swiss-table: 0x80 = empty, anything else = occupied
        buffer.initialize(to: 10, at: 0)
        buffer[metadata: 0] = 0x01
        buffer.initialize(to: 20, at: 2)
        buffer[metadata: 2] = 0x02
        // Slots 1 and 3 remain uninitialized (metadata 0x80)
        buffer.deinitialize(where: { $0 != 0x80 })
    }

    @Test
    func `withMetadataPointer provides contiguous access`() {
        var buffer = Buffer<Int>.Slots<UInt8>(capacity: 4, metadataInitial: 0x80)
        buffer[metadata: 1] = 0x42
        buffer[metadata: 3] = 0x43

        let result = unsafe buffer.withMetadataPointer { ptr in
            (unsafe ptr[0], unsafe ptr[1], unsafe ptr[2], unsafe ptr[3])
        }
        #expect(result.0 == 0x80)
        #expect(result.1 == 0x42)
        #expect(result.2 == 0x80)
        #expect(result.3 == 0x43)
    }

    @Test
    func `withMutableMetadataPointer allows mutation`() {
        let buffer = Buffer<Int>.Slots<UInt8>(capacity: 4, metadataInitial: 0x80)

        unsafe buffer.withMutableMetadataPointer { ptr in
            unsafe ptr[0] = 0xAA
            unsafe ptr[1] = 0xBB
        }
        #expect(buffer[metadata: 0] == 0xAA)
        #expect(buffer[metadata: 1] == 0xBB)
    }

    @Test
    func `pointer at returns valid element pointer`() {
        let buffer = Buffer<Int>.Slots<UInt8>(capacity: 4, metadataInitial: 0x80)
        let slot: Index<Int> = 2
        buffer.initialize(to: 55, at: slot)
        let ptr = unsafe buffer.pointer(at: slot)
        #expect(unsafe ptr.pointee == 55)
        buffer.deinitialize(at: slot)
    }

    @Test
    func `Copyable conditional conformance`() {
        var a = Buffer<Int>.Slots<UInt8>(capacity: 4, metadataInitial: 0x80)
        a.initialize(to: 10, at: 0)
        a[metadata: 0] = 0x01

        // Copy — Buffer.Slots is Copyable when Element: Copyable
        let b = a
        #expect(b[metadata: 0] == 0x01)
        #expect(b[payload: 0] == 10)

        // Both references share the same storage (class-backed),
        // so deinitialize only once
        a.deinitialize(at: 0)
    }
}

// MARK: - Edge Cases

extension SlotsTests.EdgeCase {

    @Test
    func `all metadata initially uniform`() {
        let buffer = Buffer<Int>.Slots<UInt8>(capacity: 8, metadataInitial: 0x80)
        for i: UInt in 0..<8 {
            let slot = Index<Int>(__unchecked: (), Ordinal(i))
            #expect(buffer[metadata: slot] == 0x80)
        }
    }

    @Test
    func `deinitialize where with no occupied slots is safe`() {
        let buffer = Buffer<Int>.Slots<UInt8>(capacity: 4, metadataInitial: 0x80)
        // No elements initialized — should be a no-op
        buffer.deinitialize(where: { $0 != 0x80 })
    }

    @Test
    func `deinitialize where with all occupied slots`() {
        let buffer = Buffer<Int>.Slots<UInt8>(capacity: 4, metadataInitial: 0x00)
        // metadataInitial 0x00 means "occupied" in our predicate
        buffer.initialize(to: 1, at: 0)
        buffer.initialize(to: 2, at: 1)
        buffer.initialize(to: 3, at: 2)
        buffer.initialize(to: 4, at: 3)
        buffer.deinitialize(where: { $0 == 0x00 })
    }

    @Test
    func `fill metadata then selective overwrite`() {
        var buffer = Buffer<Int>.Slots<UInt8>(capacity: 4, metadataInitial: 0x80)
        buffer.fill(metadata: 0xFF)
        buffer[metadata: 2] = 0x42
        #expect(buffer[metadata: 0] == 0xFF)
        #expect(buffer[metadata: 1] == 0xFF)
        #expect(buffer[metadata: 2] == 0x42)
        #expect(buffer[metadata: 3] == 0xFF)
    }

    @Test
    func `move leaves slot uninitialized for reuse`() {
        let buffer = Buffer<Int>.Slots<UInt8>(capacity: 4, metadataInitial: 0x80)
        let slot: Index<Int> = 0

        buffer.initialize(to: 100, at: slot)
        let moved = buffer.move(at: slot)
        #expect(moved == 100)

        // Re-initialize the same slot
        buffer.initialize(to: 200, at: slot)
        let moved2 = buffer.move(at: slot)
        #expect(moved2 == 200)
    }
}

// MARK: - Integration

extension SlotsTests.Integration {

    @Test
    func `Swiss-table lifecycle — insert, probe, delete`() {
        let empty: UInt8 = 0x80
        var buffer = Buffer<Int>.Slots<UInt8>(capacity: 8, metadataInitial: empty)

        // Insert: slot 3 gets h2=0x42, payload=100
        let slot: Index<Int> = 3
        buffer.initialize(to: 100, at: slot)
        buffer[metadata: slot] = 0x42

        // Probe: find slot via metadata, read payload
        #expect(buffer[metadata: slot] == 0x42)
        #expect(buffer[payload: slot] == 100)

        // Delete: move payload out, mark empty
        let removed = buffer.move(at: slot)
        buffer[metadata: slot] = empty
        #expect(removed == 100)
        #expect(buffer[metadata: slot] == empty)
    }

    @Test
    func `multiple slots occupied simultaneously`() {
        let empty: UInt8 = 0x80
        var buffer = Buffer<Int>.Slots<UInt8>(capacity: 8, metadataInitial: empty)

        // Populate slots 0, 2, 5, 7
        let slots: [(Index<Int>, Int, UInt8)] = [
            (0, 10, 0x01),
            (2, 20, 0x02),
            (5, 50, 0x05),
            (7, 70, 0x07),
        ]
        for (slot, value, h2) in slots {
            buffer.initialize(to: value, at: slot)
            buffer[metadata: slot] = h2
        }

        // Verify all occupied
        for (slot, value, h2) in slots {
            #expect(buffer[metadata: slot] == h2)
            #expect(buffer[payload: slot] == value)
        }

        // Verify unoccupied slots still empty
        #expect(buffer[metadata: 1] == empty)
        #expect(buffer[metadata: 3] == empty)
        #expect(buffer[metadata: 4] == empty)
        #expect(buffer[metadata: 6] == empty)

        // Cleanup via deinitialize(where:)
        buffer.deinitialize(where: { $0 != empty })
    }

    @Test
    func `metadata scan via withMetadataPointer`() {
        let empty: UInt8 = 0x80
        var buffer = Buffer<Int>.Slots<UInt8>(capacity: 8, metadataInitial: empty)
        buffer[metadata: 1] = 0x42
        buffer[metadata: 4] = 0x42
        buffer[metadata: 6] = 0x42

        // Scan for matching h2 values
        let matches = unsafe buffer.withMetadataPointer { ptr in
            var result: [Int] = []
            for i in 0..<8 {
                if unsafe ptr[i] == 0x42 {
                    result.append(i)
                }
            }
            return result
        }
        #expect(matches == [1, 4, 6])
    }
}
