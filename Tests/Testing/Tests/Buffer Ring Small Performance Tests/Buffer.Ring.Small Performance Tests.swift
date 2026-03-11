import Testing
import Buffer_Ring_Inline_Primitives
import Buffer_Primitives_Test_Support

@Suite(.serialized)
struct `Buffer.Ring.Small - Performance` {

    // MARK: - Push Back (Inline Only)

    @Test(.timed(iterations: 20, warmup: 3))
    func `push.back 64 elements inline only`() {
        var buffer = Buffer<Int>.Ring.Small<64>()
        for i in 0..<64 {
            buffer.push.back(i)
        }
        buffer.remove.all()
    }

    // MARK: - Push Back with Spill

    @Test(.timed(iterations: 20, warmup: 3))
    func `push.back 10_000 elements with spill`() {
        var buffer = Buffer<Int>.Ring.Small<64>()
        for i in 0..<10_000 {
            buffer.push.back(i)
        }
        buffer.remove.all()
    }

    // MARK: - FIFO Cycling

    @Test(.timed(iterations: 20, warmup: 3))
    func `push.back pop.front 10_000 cycles`() {
        var buffer = Buffer<Int>.Ring.Small<64>()
        buffer.push.back(0)
        for i in 1..<10_000 {
            buffer.push.back(i)
            _ = buffer.pop.front()
        }
        buffer.remove.all()
    }

    // MARK: - Fill and Reset

    @Test(.timed(iterations: 20, warmup: 3))
    func `fill and removeAll 10_000 elements 20 cycles`() {
        var buffer = Buffer<Int>.Ring.Small<64>()
        for _ in 0..<20 {
            for i in 0..<10_000 {
                buffer.push.back(i)
            }
            buffer.remove.all()
        }
    }
}
