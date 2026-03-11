import Testing
import Buffer_Linked_Primitives
import Buffer_Primitives_Test_Support

@Suite(.serialized)
struct `Buffer.Linked - Performance` {

    // MARK: - Insert Back Throughput

    @Test(.timed(iterations: 20, warmup: 3))
    func `insert.back 10_000 elements`() {
        var buffer = Buffer<Int>.Linked<2>(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            buffer.insert.back(i)
        }
        buffer.removeAll()
    }

    // MARK: - Insert Front Throughput

    @Test(.timed(iterations: 20, warmup: 3))
    func `insert.front 10_000 elements`() {
        var buffer = Buffer<Int>.Linked<2>(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            buffer.insert.front(i)
        }
        buffer.removeAll()
    }

    // MARK: - Remove Front

    @Test(.timed(iterations: 20, warmup: 3))
    func `remove.front 10_000 elements`() {
        var buffer = Buffer<Int>.Linked<2>(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            buffer.insert.back(i)
        }
        for _ in 0..<10_000 {
            _ = buffer.remove.front()
        }
    }

    // MARK: - Remove Back

    @Test(.timed(iterations: 20, warmup: 3))
    func `remove.back 10_000 elements`() {
        var buffer = Buffer<Int>.Linked<2>(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            buffer.insert.back(i)
        }
        for _ in 0..<10_000 {
            _ = buffer.remove.back()
        }
    }

    // MARK: - FIFO Cycling

    @Test(.timed(iterations: 20, warmup: 3))
    func `insert.back remove.front 10_000 cycles`() {
        var buffer = Buffer<Int>.Linked<2>(minimumCapacity: 100)
        for i in 0..<10_000 {
            buffer.insert.back(i)
            _ = buffer.remove.front()
        }
    }

    // MARK: - ForEach Traversal

    @Test(.timed(iterations: 20, warmup: 3))
    func `forEach 10_000 elements`() {
        var buffer = Buffer<Int>.Linked<2>(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            buffer.insert.back(i)
        }
        var sum = 0
        buffer.forEach { sum &+= $0 }
        _ = sum
        buffer.removeAll()
    }

    // MARK: - Growth

    @Test(.timed(iterations: 20, warmup: 3))
    func `insert.back with growth from capacity 4 to 10_000`() {
        var buffer = Buffer<Int>.Linked<2>(minimumCapacity: 4)
        for i in 0..<10_000 {
            buffer.insert.back(i)
        }
        buffer.removeAll()
    }

    // MARK: - Fill and Reset

    @Test(.timed(iterations: 20, warmup: 3))
    func `fill and removeAll 10_000 elements 20 cycles`() {
        var buffer = Buffer<Int>.Linked<2>(minimumCapacity: 10_000)
        for _ in 0..<20 {
            for i in 0..<10_000 {
                buffer.insert.back(i)
            }
            buffer.removeAll()
        }
    }
}
