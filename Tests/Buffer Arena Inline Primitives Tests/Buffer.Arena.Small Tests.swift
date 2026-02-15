import Testing
import Buffer_Arena_Inline_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Arena.Small")
struct ArenaSmallTests {

    @Test
    func `starts in inline mode`() {
        let arena = Buffer<Int>.Arena.Small<4>()
        #expect(arena.isEmpty == true)
        #expect(arena.occupied == .zero)
        #expect(arena.isSpilled == false)
    }

    @Test
    func `insert within inline capacity stays inline`() {
        var arena = Buffer<Int>.Arena.Small<4>()
        _ = arena.insert(10)
        _ = arena.insert(20)
        _ = arena.insert(30)

        #expect(arena.occupied == 3)
        #expect(arena.isSpilled == false)
    }

    @Test
    func `spill to heap when inline is full`() {
        var arena = Buffer<Int>.Arena.Small<2>()
        _ = arena.insert(10)
        _ = arena.insert(20)
        #expect(arena.isSpilled == false)

        _ = arena.insert(30)
        #expect(arena.isSpilled == true)
        #expect(arena.occupied == 3)
    }

    @Test
    func `elements survive spill`() throws {
        var arena = Buffer<Int>.Arena.Small<2>()
        let p0 = arena.insert(10)
        let p1 = arena.insert(20)
        #expect(arena.isSpilled == false)

        // Trigger spill
        let p2 = arena.insert(30)
        #expect(arena.isSpilled == true)

        // All positions remain valid after spill
        #expect(arena.isValid(p0) == true)
        #expect(arena.isValid(p1) == true)
        #expect(arena.isValid(p2) == true)

        // Remove and verify values
        let v0 = try arena.remove(at: p0)
        #expect(v0 == 10)
        let v1 = try arena.remove(at: p1)
        #expect(v1 == 20)
        let v2 = try arena.remove(at: p2)
        #expect(v2 == 30)
    }

    @Test
    func `remove in inline mode`() throws {
        var arena = Buffer<Int>.Arena.Small<4>()
        let p0 = arena.insert(10)
        let p1 = arena.insert(20)

        let value = try arena.remove(at: p0)
        #expect(value == 10)
        #expect(arena.occupied == 1)
        #expect(arena.isValid(p0) == false)
        #expect(arena.isValid(p1) == true)
    }

    @Test
    func `remove in heap mode`() throws {
        var arena = Buffer<Int>.Arena.Small<2>()
        _ = arena.insert(10)
        _ = arena.insert(20)
        let p2 = arena.insert(30)
        #expect(arena.isSpilled == true)

        let value = try arena.remove(at: p2)
        #expect(value == 30)
        #expect(arena.occupied == 2)
    }

    @Test
    func `removeAll clears arena`() {
        var arena = Buffer<Int>.Arena.Small<4>()
        let p0 = arena.insert(10)
        let p1 = arena.insert(20)
        arena.removeAll()

        #expect(arena.isEmpty == true)
        #expect(arena.occupied == .zero)
        #expect(arena.isValid(p0) == false)
        #expect(arena.isValid(p1) == false)
    }

    @Test
    func `isValid and isOccupied in inline mode`() {
        var arena = Buffer<Int>.Arena.Small<4>()
        let pos = arena.insert(42)
        #expect(arena.isOccupied(pos.slot) == true)
        #expect(arena.isValid(pos) == true)

        arena.free(at: pos.slot)
        #expect(arena.isOccupied(pos.slot) == false)
        #expect(arena.isValid(pos) == false)
    }

    @Test
    func `isValid and isOccupied in heap mode`() {
        var arena = Buffer<Int>.Arena.Small<2>()
        _ = arena.insert(10)
        _ = arena.insert(20)
        let pos = arena.insert(30)
        #expect(arena.isSpilled == true)

        #expect(arena.isOccupied(pos.slot) == true)
        #expect(arena.isValid(pos) == true)

        arena.free(at: pos.slot)
        #expect(arena.isOccupied(pos.slot) == false)
        #expect(arena.isValid(pos) == false)
    }

    @Test
    func `ensureUnique in heap mode`() {
        var arena = Buffer<Int>.Arena.Small<2>()
        _ = arena.insert(10)
        _ = arena.insert(20)
        _ = arena.insert(30)
        #expect(arena.isSpilled == true)

        // Uniquely referenced — no copy needed
        let didCopy = arena.ensureUnique()
        #expect(didCopy == false)
    }

    @Test
    func `ensureUnique in inline mode returns false`() {
        var arena = Buffer<Int>.Arena.Small<4>()
        _ = arena.insert(10)

        let didCopy = arena.ensureUnique()
        #expect(didCopy == false)
    }

    @Test
    func `token access in both modes`() {
        var arena = Buffer<Int>.Arena.Small<2>()
        let p0 = arena.insert(10)

        // Inline mode
        let t0 = arena.token(at: p0.slot)
        #expect(t0 == p0.token)
        #expect(t0 & 1 == 1)

        let reconstructed0 = arena.position(forOccupied: p0.slot)
        #expect(reconstructed0 == p0)

        // Spill to heap
        _ = arena.insert(20)
        let p2 = arena.insert(30)
        #expect(arena.isSpilled == true)

        let t2 = arena.token(at: p2.slot)
        #expect(t2 == p2.token)
        #expect(t2 & 1 == 1)

        let reconstructed2 = arena.position(forOccupied: p2.slot)
        #expect(reconstructed2 == p2)
    }
}
