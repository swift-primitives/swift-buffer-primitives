import Testing
import Buffer_Ring_Inline_Primitives
import Buffer_Primitives_Test_Support

@Suite(.serialized)
struct `Buffer.Ring.Inline - Performance` {

    // MARK: - Push Back Throughput

    @Test(.timed(iterations: 20, warmup: 3))
    func `push.back 256 elements`() {
        var buffer = Buffer<Int>.Ring.Inline<256>()
        for i in 0..<256 {
            _ = buffer.push.back(i)
        }
        buffer.remove.all()
    }

    // MARK: - Push Front Throughput

    @Test(.timed(iterations: 20, warmup: 3))
    func `push.front 256 elements`() {
        var buffer = Buffer<Int>.Ring.Inline<256>()
        for i in 0..<256 {
            _ = buffer.push.front(i)
        }
        buffer.remove.all()
    }

    // MARK: - Pop Front

    @Test(.timed(iterations: 20, warmup: 3))
    func `pop.front 256 elements`() {
        var buffer = Buffer<Int>.Ring.Inline<256>()
        for i in 0..<256 {
            _ = buffer.push.back(i)
        }
        for _ in 0..<256 {
            _ = buffer.pop.front()
        }
    }

    // MARK: - FIFO Cycling

    @Test(.timed(iterations: 20, warmup: 3))
    func `push.back pop.front 256 cycles`() {
        var buffer = Buffer<Int>.Ring.Inline<256>()
        _ = buffer.push.back(0)
        for i in 1..<256 {
            _ = buffer.push.back(i)
            _ = buffer.pop.front()
        }
        buffer.remove.all()
    }

    // MARK: - Fill and Reset

    @Test(.timed(iterations: 20, warmup: 3))
    func `fill and removeAll 256 elements 20 cycles`() {
        var buffer = Buffer<Int>.Ring.Inline<256>()
        for _ in 0..<20 {
            for i in 0..<256 {
                _ = buffer.push.back(i)
            }
            buffer.remove.all()
        }
    }
}
