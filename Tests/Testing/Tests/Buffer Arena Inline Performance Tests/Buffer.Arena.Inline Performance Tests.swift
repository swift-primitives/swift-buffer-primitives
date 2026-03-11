import Testing
import Buffer_Arena_Inline_Primitives
import Buffer_Primitives_Test_Support

@Suite(.serialized)
struct `Buffer.Arena.Inline - Performance` {

    // MARK: - Insert Throughput

    @Test(.timed(iterations: 20, warmup: 3))
    func `insert 256 elements`() throws {
        var arena = Buffer<Int>.Arena.Inline<256>()
        for i in 0..<256 {
            _ = try arena.insert(i)
        }
        arena.removeAll()
    }

    // MARK: - Remove by Position

    @Test(.timed(iterations: 20, warmup: 3))
    func `remove 256 elements by position`() throws {
        var arena = Buffer<Int>.Arena.Inline<256>()
        var positions: [Buffer<Int>.Arena.Position] = []
        positions.reserveCapacity(256)
        for i in 0..<256 {
            positions.append(try arena.insert(i))
        }
        for position in positions {
            _ = try arena.remove(at: position)
        }
    }

    // MARK: - Insert-Free Cycling

    @Test(.timed(iterations: 20, warmup: 3))
    func `insert-free 256 cycles`() throws {
        var arena = Buffer<Int>.Arena.Inline<256>()
        for i in 0..<256 {
            let pos = try arena.insert(i)
            _ = arena.remove(at: pos.slot)
        }
    }

    // MARK: - Fill and Reset

    @Test(.timed(iterations: 20, warmup: 3))
    func `fill and removeAll 256 elements 20 cycles`() throws {
        var arena = Buffer<Int>.Arena.Inline<256>()
        for _ in 0..<20 {
            for i in 0..<256 {
                _ = try arena.insert(i)
            }
            arena.removeAll()
        }
    }
}
