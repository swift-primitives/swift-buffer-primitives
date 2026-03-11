import Testing
import Buffer_Ring_Primitives
import Buffer_Primitives_Test_Support

@Suite(.serialized)
struct `Buffer.Ring - Performance` {

    // MARK: - Push Back Throughput

    @Test(.timed(iterations: 20, warmup: 3))
    func `push.back 10_000 elements`() {
        var buffer = Buffer<Int>.Ring(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            buffer.push.back(i)
        }
        buffer.remove.all()
    }

    // MARK: - Push Front Throughput

    @Test(.timed(iterations: 20, warmup: 3))
    func `push.front 10_000 elements`() {
        var buffer = Buffer<Int>.Ring(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            buffer.push.front(i)
        }
        buffer.remove.all()
    }

    // MARK: - Pop Front

    @Test(.timed(iterations: 20, warmup: 3))
    func `pop.front 10_000 elements`() {
        var buffer = Buffer<Int>.Ring(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            buffer.push.back(i)
        }
        for _ in 0..<10_000 {
            _ = buffer.pop.front()
        }
    }

    // MARK: - Pop Back

    @Test(.timed(iterations: 20, warmup: 3))
    func `pop.back 10_000 elements`() {
        var buffer = Buffer<Int>.Ring(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            buffer.push.back(i)
        }
        for _ in 0..<10_000 {
            _ = buffer.pop.back()
        }
    }

    // MARK: - FIFO Cycling

    @Test(.timed(iterations: 20, warmup: 3))
    func `push.back pop.front 10_000 cycles`() {
        var buffer = Buffer<Int>.Ring(minimumCapacity: 100)
        for i in 0..<10_000 {
            buffer.push.back(i)
            _ = buffer.pop.front()
        }
    }

    // MARK: - Drain

    @Test(.timed(iterations: 20, warmup: 3))
    func `drain 10_000 elements`() {
        var buffer = Buffer<Int>.Ring(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            buffer.push.back(i)
        }
        var sum = 0
        buffer.drain { sum &+= $0 }
        _ = sum
    }

    // MARK: - Growth

    @Test(.timed(iterations: 20, warmup: 3))
    func `push.back with growth from capacity 1 to 10_000`() {
        var buffer = Buffer<Int>.Ring(minimumCapacity: 1)
        for i in 0..<10_000 {
            buffer.push.back(i)
        }
        buffer.remove.all()
    }

    // MARK: - Fill and Reset

    @Test(.timed(iterations: 20, warmup: 3))
    func `fill and removeAll 10_000 elements 20 cycles`() {
        var buffer = Buffer<Int>.Ring(minimumCapacity: 10_000)
        for _ in 0..<20 {
            for i in 0..<10_000 {
                buffer.push.back(i)
            }
            buffer.remove.all()
        }
    }
}
