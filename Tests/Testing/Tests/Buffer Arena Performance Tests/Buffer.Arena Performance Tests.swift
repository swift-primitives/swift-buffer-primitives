import Testing
import Buffer_Arena_Primitives
import Buffer_Primitives_Test_Support

@Suite(.serialized)
struct `Buffer.Arena - Performance` {

    // MARK: - Insert Throughput

    @Test(.timed(iterations: 20, warmup: 3))
    func `insert 10_000 elements`() {
        var arena = Buffer<Int>.Arena(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            _ = arena.insert(i)
        }
        arena.removeAll()
    }

    // MARK: - Remove by Position

    @Test(.timed(iterations: 20, warmup: 3))
    func `remove 10_000 elements by position`() throws {
        var arena = Buffer<Int>.Arena(minimumCapacity: 10_000)
        var positions: [Buffer<Int>.Arena.Position] = []
        positions.reserveCapacity(10_000)
        for i in 0..<10_000 {
            positions.append(arena.insert(i))
        }
        for position in positions {
            _ = try arena.remove(at: position)
        }
    }

    // MARK: - Remove by Slot

    @Test(.timed(iterations: 20, warmup: 3))
    func `remove 10_000 elements by slot`() {
        var arena = Buffer<Int>.Arena(minimumCapacity: 10_000)
        var positions: [Buffer<Int>.Arena.Position] = []
        positions.reserveCapacity(10_000)
        for i in 0..<10_000 {
            positions.append(arena.insert(i))
        }
        for position in positions {
            _ = arena.remove(at: position.slot)
        }
    }

    // MARK: - Insert-Free Cycling (LIFO Reuse)

    @Test(.timed(iterations: 20, warmup: 3))
    func `insert-free 10_000 cycles`() {
        var arena = Buffer<Int>.Arena(minimumCapacity: 100)
        for i in 0..<10_000 {
            let pos = arena.insert(i)
            arena.free(at: pos.slot)
        }
    }

    // MARK: - Position Validation

    @Test(.timed(iterations: 20, warmup: 3))
    func `isValid check 10_000 positions`() {
        var arena = Buffer<Int>.Arena(minimumCapacity: 10_000)
        var positions: [Buffer<Int>.Arena.Position] = []
        positions.reserveCapacity(10_000)
        for i in 0..<10_000 {
            positions.append(arena.insert(i))
        }
        var count = 0
        for position in positions {
            if arena.isValid(position) {
                count &+= 1
            }
        }
        _ = count
        arena.removeAll()
    }

    // MARK: - Fill and Reset

    @Test(.timed(iterations: 20, warmup: 3))
    func `fill and removeAll 10_000 elements 20 cycles`() {
        var arena = Buffer<Int>.Arena(minimumCapacity: 10_000)
        for _ in 0..<20 {
            for i in 0..<10_000 {
                _ = arena.insert(i)
            }
            arena.removeAll()
        }
    }
}
