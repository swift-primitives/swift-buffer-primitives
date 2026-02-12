import Testing
import Buffer_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Arena.Inline")
struct ArenaInlineTests {

    @Test
    func `init creates empty inline arena`() {
        let arena = Buffer<Int>.Arena.Inline<8>()
        #expect(arena.isEmpty == true)
        #expect(arena.occupied == .zero)
        #expect(arena.isFull == false)
    }

    @Test
    func `insert and remove via position`() throws {
        var arena = Buffer<Int>.Arena.Inline<8>()
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
        var arena = Buffer<Int>.Arena.Inline<2>()
        _ = try arena.insert(10)
        _ = try arena.insert(20)
        #expect(arena.isFull == true)

        do {
            _ = try arena.insert(30)
            Issue.record("Expected .capacityExceeded error")
        } catch {
            #expect(error == .capacityExceeded)
        }
    }

    @Test
    func `free and reinsert — slot reuse`() throws {
        var arena = Buffer<Int>.Arena.Inline<4>()
        let p0 = try arena.insert(10)
        arena.free(at: p0.slot)

        let p1 = try arena.insert(20)
        #expect(p0.index == p1.index)
        #expect(p0.token != p1.token)
        #expect(arena.isValid(p0) == false)
        #expect(arena.isValid(p1) == true)
    }

    @Test
    func `isValid and isOccupied`() throws {
        var arena = Buffer<Int>.Arena.Inline<4>()
        let pos = try arena.insert(42)
        #expect(arena.isOccupied(pos.slot) == true)
        #expect(arena.isValid(pos) == true)

        arena.free(at: pos.slot)
        #expect(arena.isOccupied(pos.slot) == false)
        #expect(arena.isValid(pos) == false)
    }

    @Test
    func `removeAll clears arena`() throws {
        var arena = Buffer<Int>.Arena.Inline<4>()
        let p0 = try arena.insert(10)
        let p1 = try arena.insert(20)
        arena.removeAll()

        #expect(arena.isEmpty == true)
        #expect(arena.occupied == .zero)
        #expect(arena.isValid(p0) == false)
        #expect(arena.isValid(p1) == false)
    }

    @Test
    func `token access and position construction`() throws {
        var arena = Buffer<Int>.Arena.Inline<4>()
        let pos = try arena.insert(42)

        let t = arena.token(at: pos.slot)
        #expect(t == pos.token)
        #expect(t & 1 == 1)

        let reconstructed = arena.position(forOccupied: pos.slot)
        #expect(reconstructed == pos)
    }

    @Test
    func `remove by slot index`() throws {
        var arena = Buffer<Int>.Arena.Inline<4>()
        _ = try arena.insert(10)
        let p1 = try arena.insert(20)
        _ = try arena.insert(30)

        let removed = arena.remove(at: p1.slot)
        #expect(removed == 20)
        #expect(arena.occupied == 2)
        #expect(arena.isOccupied(p1.slot) == false)
    }

    @Test
    func `allocate reserves slot`() throws {
        var arena = Buffer<Int>.Arena.Inline<4>()
        let pos = try arena.allocate()
        #expect(arena.occupied == 1)
        #expect(arena.isValid(pos) == true)
        #expect(arena.isOccupied(pos.slot) == true)
    }

    @Test
    func `remove with invalid position throws`() throws {
        var arena = Buffer<Int>.Arena.Inline<4>()
        let pos = try arena.insert(42)
        arena.free(at: pos.slot)

        do {
            _ = try arena.remove(at: pos)
            Issue.record("Expected invalidPosition error")
        } catch {
            #expect(error == .invalidPosition)
        }
    }
}
