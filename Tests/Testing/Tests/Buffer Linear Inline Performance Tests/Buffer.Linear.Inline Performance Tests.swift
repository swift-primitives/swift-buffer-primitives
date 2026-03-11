import Testing
import Buffer_Linear_Inline_Primitives
import Buffer_Primitives_Test_Support

@Suite(.serialized)
struct `Buffer.Linear.Inline - Performance` {

    // MARK: - Append Throughput

    @Test(.timed(iterations: 20, warmup: 3))
    func `append 256 elements`() {
        var buffer = Buffer<Int>.Linear.Inline<256>()
        for i in 0..<256 {
            _ = buffer.append(i)
        }
        buffer.remove.all()
    }

    // MARK: - Sequential Read

    @Test(.timed(iterations: 20, warmup: 3))
    func `subscript read 256 elements`() {
        var buffer = Buffer<Int>.Linear.Inline<256>()
        for i in 0..<256 {
            _ = buffer.append(i)
        }
        var sum = 0
        for i in 0..<256 {
            let slot = Index<Int>.Bounded<256>(Index<Int>(Ordinal(UInt(i))))!
            sum &+= buffer[slot]
        }
        _ = sum
        buffer.remove.all()
    }

    // MARK: - Remove Last

    @Test(.timed(iterations: 20, warmup: 3))
    func `removeLast 256 elements`() {
        var buffer = Buffer<Int>.Linear.Inline<256>()
        for i in 0..<256 {
            _ = buffer.append(i)
        }
        for _ in 0..<256 {
            _ = buffer.remove.last()
        }
    }

    // MARK: - Remove First

    @Test(.timed(iterations: 20, warmup: 3))
    func `removeFirst 256 elements`() {
        var buffer = Buffer<Int>.Linear.Inline<256>()
        for i in 0..<256 {
            _ = buffer.append(i)
        }
        for _ in 0..<256 {
            _ = buffer.remove.first()
        }
    }

    // MARK: - Fill and Reset

    @Test(.timed(iterations: 20, warmup: 3))
    func `fill and removeAll 256 elements 20 cycles`() {
        var buffer = Buffer<Int>.Linear.Inline<256>()
        for _ in 0..<20 {
            for i in 0..<256 {
                _ = buffer.append(i)
            }
            buffer.remove.all()
        }
    }
}
