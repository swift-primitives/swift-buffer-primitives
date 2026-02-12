import Testing
import Buffer_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Arena.Bounded")
struct ArenaBoundedTests_Standalone {

    @Test
    func `init creates empty bounded arena`() {
        let arena = Buffer<Int>.Arena.Bounded(minimumCapacity: 8)
        #expect(arena.isEmpty == true)
        #expect(arena.occupied == .zero)
        #expect(arena.isFull == false)
    }

    @Test
    func `insert and remove via position`() throws {
        var arena = Buffer<Int>.Arena.Bounded(minimumCapacity: 4)
        let pos = try arena.insert(42)
        #expect(arena.occupied == 1)
        #expect(arena.isValid(pos) == true)

        let value = try arena.remove(at: pos)
        #expect(value == 42)
        #expect(arena.isEmpty == true)
        #expect(arena.isValid(pos) == false)
    }

    @Test
    func `insert throws capacityExceeded when full`() throws {
        var arena = Buffer<Int>.Arena.Bounded(minimumCapacity: 2)
        var i = 0
        while arena.isFull == false {
            _ = try arena.insert(i)
            i += 1
        }

        do {
            _ = try arena.insert(i)
            Issue.record("Expected .capacityExceeded error")
        } catch {
            #expect(error == .capacityExceeded)
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
        arena.free(at: positions[0].slot)
        #expect(arena.isFull == false)

        let pNew = try arena.insert(99)
        #expect(arena.isValid(pNew) == true)
        #expect(arena.isValid(positions[0]) == false)
    }

    @Test
    func `stale handle detection`() throws {
        var arena = Buffer<Int>.Arena.Bounded(minimumCapacity: 4)
        let p1 = try arena.insert(100)
        arena.free(at: p1.slot)

        let p2 = try arena.insert(200)
        #expect(p1.index == p2.index)
        #expect(p1.token != p2.token)
        #expect(arena.isValid(p1) == false)
        #expect(arena.isValid(p2) == true)
    }

    @Test
    func `token access`() throws {
        var arena = Buffer<Int>.Arena.Bounded(minimumCapacity: 4)
        let pos = try arena.insert(42)

        let t = arena.token(at: pos.slot)
        #expect(t == pos.token)
        #expect(t & 1 == 1)

        let reconstructed = arena.position(forOccupied: pos.slot)
        #expect(reconstructed == pos)
    }

    @Test
    func `isValid and isOccupied`() throws {
        var arena = Buffer<Int>.Arena.Bounded(minimumCapacity: 4)
        let pos = try arena.insert(42)
        #expect(arena.isOccupied(pos.slot) == true)
        #expect(arena.isValid(pos) == true)

        arena.free(at: pos.slot)
        #expect(arena.isOccupied(pos.slot) == false)
        #expect(arena.isValid(pos) == false)
    }

    @Test
    func `forEach visits occupied slots`() throws {
        var arena = Buffer<Int>.Arena.Bounded(minimumCapacity: 8)
        let p0 = try arena.insert(10)
        let p1 = try arena.insert(20)
        let p2 = try arena.insert(30)

        arena.free(at: p1.slot)

        var visited: [UInt32] = []
        arena.forEach.occupied { (slot: Index<Int>) in
            visited.append(UInt32(slot.rawValue.rawValue))
        }
        #expect(visited.sorted() == [p0.index, p2.index].sorted())
    }

    @Test
    func `removeAll clears arena`() throws {
        var arena = Buffer<Int>.Arena.Bounded(minimumCapacity: 4)
        let p0 = try arena.insert(10)
        let p1 = try arena.insert(20)
        arena.removeAll()

        #expect(arena.isEmpty == true)
        #expect(arena.occupied == .zero)
        #expect(arena.isValid(p0) == false)
        #expect(arena.isValid(p1) == false)

        let p2 = try arena.insert(30)
        #expect(arena.occupied == 1)
        #expect(arena.isValid(p2) == true)
    }

    @Test
    func `ensureUnique copies shared storage`() throws {
        var arena = Buffer<Int>.Arena.Bounded(minimumCapacity: 4)
        _ = try arena.insert(10)
        _ = try arena.insert(20)

        var copy = arena
        let didCopy = copy.ensureUnique()
        #expect(didCopy == true)

        let secondCall = copy.ensureUnique()
        #expect(secondCall == false)
    }
}
