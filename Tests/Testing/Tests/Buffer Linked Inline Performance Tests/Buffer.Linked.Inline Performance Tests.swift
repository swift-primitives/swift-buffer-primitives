import Testing
import Buffer_Linked_Inline_Primitives
import Buffer_Primitives_Test_Support

@Suite(.serialized)
struct `Buffer.Linked.Inline - Performance` {

    // MARK: - Insert Back Throughput

    @Test(.timed(iterations: 20, warmup: 3))
    func `insert.back 256 elements`() throws {
        var buffer = Buffer<Int>.Linked<2>.Inline<256>()
        for i in 0..<256 {
            try buffer.insert.back(i)
        }
        buffer.removeAll()
    }

    // MARK: - Insert Front Throughput

    @Test(.timed(iterations: 20, warmup: 3))
    func `insert.front 256 elements`() throws {
        var buffer = Buffer<Int>.Linked<2>.Inline<256>()
        for i in 0..<256 {
            try buffer.insert.front(i)
        }
        buffer.removeAll()
    }

    // MARK: - Remove Front

    @Test(.timed(iterations: 20, warmup: 3))
    func `remove.front 256 elements`() throws {
        var buffer = Buffer<Int>.Linked<2>.Inline<256>()
        for i in 0..<256 {
            try buffer.insert.back(i)
        }
        for _ in 0..<256 {
            _ = buffer.remove.front()
        }
    }

    // MARK: - FIFO Cycling

    @Test(.timed(iterations: 20, warmup: 3))
    func `insert.back remove.front 256 cycles`() throws {
        var buffer = Buffer<Int>.Linked<2>.Inline<256>()
        try buffer.insert.back(0)
        for i in 1..<256 {
            try buffer.insert.back(i)
            _ = buffer.remove.front()
        }
        buffer.removeAll()
    }

    // MARK: - Fill and Reset

    @Test(.timed(iterations: 20, warmup: 3))
    func `fill and removeAll 256 elements 20 cycles`() throws {
        var buffer = Buffer<Int>.Linked<2>.Inline<256>()
        for _ in 0..<20 {
            for i in 0..<256 {
                try buffer.insert.back(i)
            }
            buffer.removeAll()
        }
    }
}
