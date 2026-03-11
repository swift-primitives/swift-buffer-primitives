import Testing
import Buffer_Linear_Small_Primitives
import Buffer_Primitives_Test_Support

@Suite(.serialized)
struct `Buffer.Linear.Small - Performance` {

    // MARK: - Append (Inline Only)

    @Test(.timed(iterations: 20, warmup: 3))
    func `append 64 elements inline only`() {
        var buffer = Buffer<Int>.Linear.Small<64>()
        for i in 0..<64 {
            buffer.append(i)
        }
        buffer.remove.all()
    }

    // MARK: - Append with Spill

    @Test(.timed(iterations: 20, warmup: 3))
    func `append 10_000 elements with spill`() {
        var buffer = Buffer<Int>.Linear.Small<64>()
        for i in 0..<10_000 {
            buffer.append(i)
        }
        buffer.remove.all()
    }

    // MARK: - Remove Last

    @Test(.timed(iterations: 20, warmup: 3))
    func `removeLast 10_000 elements`() {
        var buffer = Buffer<Int>.Linear.Small<64>()
        for i in 0..<10_000 {
            buffer.append(i)
        }
        for _ in 0..<10_000 {
            _ = buffer.remove.last()
        }
    }

    // MARK: - Fill and Reset

    @Test(.timed(iterations: 20, warmup: 3))
    func `fill and removeAll 10_000 elements 20 cycles`() {
        var buffer = Buffer<Int>.Linear.Small<64>()
        for _ in 0..<20 {
            for i in 0..<10_000 {
                buffer.append(i)
            }
            buffer.remove.all()
        }
    }
}
