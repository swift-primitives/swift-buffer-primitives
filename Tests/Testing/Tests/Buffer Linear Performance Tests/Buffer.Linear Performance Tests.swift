import Testing
import Buffer_Linear_Primitives
import Buffer_Primitives_Test_Support

@Suite(.serialized)
struct `Buffer.Linear - Performance` {

    // MARK: - Append Throughput

    @Test(.timed(iterations: 20, warmup: 3))
    func `append 10_000 elements`() {
        var buffer = Buffer<Int>.Linear(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            buffer.append(i)
        }
        buffer.remove.all()
    }

    // MARK: - Sequential Read

    @Test(.timed(iterations: 20, warmup: 3))
    func `subscript read 10_000 elements`() {
        var buffer = Buffer<Int>.Linear(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            buffer.append(i)
        }
        var sum = 0
        for i in 0..<10_000 {
            let index = Index<Int>(Ordinal(UInt(i)))
            sum &+= buffer[index]
        }
        _ = sum
        buffer.remove.all()
    }

    // MARK: - Remove Last

    @Test(.timed(iterations: 20, warmup: 3))
    func `removeLast 10_000 elements`() {
        var buffer = Buffer<Int>.Linear(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            buffer.append(i)
        }
        for _ in 0..<10_000 {
            _ = buffer.remove.last()
        }
    }

    // MARK: - Remove First

    @Test(.timed(iterations: 20, warmup: 3))
    func `removeFirst 10_000 elements`() {
        var buffer = Buffer<Int>.Linear(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            buffer.append(i)
        }
        for _ in 0..<10_000 {
            _ = buffer.remove.first()
        }
    }

    // MARK: - Drain

    @Test(.timed(iterations: 20, warmup: 3))
    func `drain 10_000 elements`() {
        var buffer = Buffer<Int>.Linear(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            buffer.append(i)
        }
        var sum = 0
        buffer.drain { sum &+= $0 }
        _ = sum
    }

    // MARK: - Growth

    @Test(.timed(iterations: 20, warmup: 3))
    func `append with growth from capacity 1 to 10_000`() {
        var buffer = Buffer<Int>.Linear(minimumCapacity: 1)
        for i in 0..<10_000 {
            buffer.append(i)
        }
        buffer.remove.all()
    }

    // MARK: - Fill and Reset

    @Test(.timed(iterations: 20, warmup: 3))
    func `fill and removeAll 10_000 elements 20 cycles`() {
        var buffer = Buffer<Int>.Linear(minimumCapacity: 10_000)
        for _ in 0..<20 {
            for i in 0..<10_000 {
                buffer.append(i)
            }
            buffer.remove.all()
        }
    }
}
