import Testing
import Buffer_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Arena")
struct ArenaTests {

    @Test
    func `insert and remove via position`() throws {
        var arena = Buffer<Int>.Arena(minimumCapacity: 4)
        let pos = arena.insert(42)
        #expect(arena.occupied == 1)
        #expect(arena.isValid(pos) == true)

        let value = try arena.remove(at: pos)
        #expect(value == 42)
        #expect(arena.isEmpty == true)
        #expect(arena.isValid(pos) == false)
    }

    @Test
    func `insert multiple and remove by slot index`() {
        var arena = Buffer<Int>.Arena(minimumCapacity: 8)
        let p0 = arena.insert(10)
        let p1 = arena.insert(20)
        let p2 = arena.insert(30)
        #expect(arena.occupied == 3)

        let removed = arena.remove(at: p1.slotIndex)
        #expect(removed == 20)
        #expect(arena.occupied == 2)
        #expect(arena.isValid(p0) == true)
        #expect(arena.isValid(p1) == false)
        #expect(arena.isValid(p2) == true)
    }

    @Test
    func `stale handle detection after reuse`() {
        var arena = Buffer<Int>.Arena(minimumCapacity: 4)
        let p1 = arena.insert(100)
        arena.freeSlot(at: p1.slotIndex)

        // Reallocate same slot (LIFO freelist)
        let p2 = arena.insert(200)
        #expect(p1.index == p2.index)
        #expect(p1.token != p2.token)
        #expect(arena.isValid(p1) == false)
        #expect(arena.isValid(p2) == true)
    }

    @Test
    func `allocate free allocate — LIFO reuse`() {
        var arena = Buffer<Int>.Arena(minimumCapacity: 4)
        let p0 = arena.insert(0)
        _ = arena.insert(1)
        let p2 = arena.insert(2)

        // Free in order: 2, 0 (skip 1)
        arena.freeSlot(at: p2.slotIndex)
        arena.freeSlot(at: p0.slotIndex)

        // LIFO: next allocate should reuse slot 0 (last freed), then slot 2
        let r0 = arena.insert(10)
        let r1 = arena.insert(20)
        #expect(r0.index == p0.index)
        #expect(r1.index == p2.index)
    }

    @Test
    func `forEachOccupied visits correct slots`() {
        var arena = Buffer<Int>.Arena(minimumCapacity: 8)
        let p0 = arena.insert(10)
        _ = arena.insert(20)
        let p2 = arena.insert(30)

        // Free the middle one
        arena.freeSlot(at: Index<Int>(Ordinal(UInt(1))))

        var visited: [UInt32] = []
        arena.forEachOccupied { slot in
            visited.append(UInt32(slot.rawValue.rawValue))
        }
        #expect(visited.sorted() == [p0.index, p2.index].sorted())
    }

    @Test
    func `removeAll resets to empty`() {
        var arena = Buffer<Int>.Arena(minimumCapacity: 4)
        let p0 = arena.insert(10)
        let p1 = arena.insert(20)
        arena.removeAll()

        #expect(arena.isEmpty == true)
        #expect(arena.occupied == .zero)
        #expect(arena.isValid(p0) == false)
        #expect(arena.isValid(p1) == false)

        // Can reuse after removeAll
        let p2 = arena.insert(30)
        #expect(arena.occupied == 1)
        #expect(arena.isValid(p2) == true)
    }

    @Test
    func `growth preserves positions and elements`() throws {
        // Start small to force growth
        var arena = Buffer<Int>.Arena(minimumCapacity: 2)
        var positions: [Buffer<Int>.Arena.Position] = []

        // Fill beyond initial capacity
        for i in 0..<10 {
            positions.append(arena.insert(i * 100))
        }
        #expect(arena.occupied == 10)

        // All positions still valid, all elements intact
        for (i, pos) in positions.enumerated() {
            #expect(arena.isValid(pos) == true)
            let value = try arena.remove(at: pos)
            #expect(value == i * 100)
        }
        #expect(arena.isEmpty == true)
    }

    @Test
    func `growth with non-empty freelist`() throws {
        var arena = Buffer<Int>.Arena(minimumCapacity: 4)

        // Fill to capacity
        let p0 = arena.insert(0)
        let p1 = arena.insert(1)
        let p2 = arena.insert(2)
        let p3 = arena.insert(3)

        // Free some to populate freelist
        arena.freeSlot(at: p1.slotIndex)
        arena.freeSlot(at: p3.slotIndex)

        // Fill freelist slots
        let r1 = arena.insert(11)
        let r3 = arena.insert(33)

        // Now force growth by filling to capacity again
        let p4 = arena.insert(4)
        #expect(arena.occupied == 5)

        // Old surviving positions still valid
        #expect(arena.isValid(p0) == true)
        #expect(arena.isValid(p2) == true)
        #expect(arena.isValid(r1) == true)
        #expect(arena.isValid(r3) == true)
        #expect(arena.isValid(p4) == true)
    }

    @Test
    func `isOccupied matches token parity`() {
        var arena = Buffer<Int>.Arena(minimumCapacity: 4)
        let pos = arena.insert(42)
        #expect(arena.isOccupied(pos.slotIndex) == true)

        arena.freeSlot(at: pos.slotIndex)
        #expect(arena.isOccupied(pos.slotIndex) == false)
    }

    @Test
    func `token access and position construction`() {
        var arena = Buffer<Int>.Arena(minimumCapacity: 4)
        let pos = arena.insert(42)

        let t = arena.token(at: pos.slotIndex)
        #expect(t == pos.token)
        #expect(t & 1 == 1) // occupied = odd

        let reconstructed = arena.position(forOccupied: pos.slotIndex)
        #expect(reconstructed == pos)
    }

    @Test
    func `remove with invalid position throws`() {
        var arena = Buffer<Int>.Arena(minimumCapacity: 4)
        let pos = arena.insert(42)
        arena.freeSlot(at: pos.slotIndex)

        do {
            _ = try arena.remove(at: pos)
            Issue.record("Expected invalidPosition error")
        } catch {
            #expect(error == .invalidPosition)
        }
    }

    @Test
    func `deinit cleans up occupied slots`() {
        var arena = Buffer<Int>.Arena(minimumCapacity: 4)
        _ = arena.insert(10)
        _ = arena.insert(20)
        _ = arena.insert(30)
        // arena deinitialized at function exit — no crash verifies cleanup
    }
}

@Suite("Buffer.Arena.Bounded")
struct ArenaBoundedTests {

    @Test
    func `insert and remove`() throws {
        var arena = Buffer<Int>.Arena.Bounded(minimumCapacity: 4)
        let pos = try arena.insert(42)
        #expect(arena.occupied == 1)
        #expect(arena.isValid(pos) == true)

        let value = try arena.remove(at: pos)
        #expect(value == 42)
        #expect(arena.isEmpty == true)
    }

    @Test
    func `full arena throws`() throws {
        var arena = Buffer<Int>.Arena.Bounded(minimumCapacity: 2)
        var i = 0
        while arena.isFull == false {
            _ = try arena.insert(i)
            i += 1
        }

        do {
            _ = try arena.insert(i)
            Issue.record("Expected .full error")
        } catch {
            #expect(error == .full)
        }
    }

    @Test
    func `free one then allocate succeeds`() throws {
        var arena = Buffer<Int>.Arena.Bounded(minimumCapacity: 2)
        var positions: [Buffer<Int>.Arena.Position] = []
        var i = 0
        while arena.isFull == false {
            positions.append(try arena.insert(i))
            i += 1
        }

        #expect(arena.isFull == true)
        arena.freeSlot(at: positions[0].slotIndex)
        #expect(arena.isFull == false)

        let pNew = try arena.insert(99)
        #expect(arena.isValid(pNew) == true)
        #expect(arena.isValid(positions[0]) == false)
    }

    @Test
    func `deinit cleans up occupied slots`() throws {
        var arena = Buffer<Int>.Arena.Bounded(minimumCapacity: 4)
        _ = try arena.insert(10)
        _ = try arena.insert(20)
        // arena deinitialized at function exit — no crash verifies cleanup
    }
}
