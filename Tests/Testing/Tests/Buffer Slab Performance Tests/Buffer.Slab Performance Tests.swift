import Testing
import Buffer_Slab_Primitives
import Buffer_Primitives_Test_Support

@Suite(.serialized)
struct `Buffer.Slab - Performance` {

    // MARK: - Insert Throughput

    @Test(.timed(iterations: 20, warmup: 3))
    func `insert 10_000 elements at sequential slots`() {
        var buffer = Buffer<Int>.Slab(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            let slot: Bit.Index = Bit.Index(Ordinal(UInt(i)))
            buffer.insert(i, at: slot)
        }
        buffer.removeAll()
    }

    // MARK: - Remove Throughput

    @Test(.timed(iterations: 20, warmup: 3))
    func `remove 10_000 elements from sequential slots`() {
        var buffer = Buffer<Int>.Slab(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            let slot: Bit.Index = Bit.Index(Ordinal(UInt(i)))
            buffer.insert(i, at: slot)
        }
        for i in 0..<10_000 {
            let slot: Bit.Index = Bit.Index(Ordinal(UInt(i)))
            _ = buffer.remove(at: slot)
        }
    }

    // MARK: - Insert-Remove Cycling

    @Test(.timed(iterations: 20, warmup: 3))
    func `insert-remove 10_000 cycles at slot 0`() {
        var buffer = Buffer<Int>.Slab(minimumCapacity: 100)
        let slot: Bit.Index = 0
        for i in 0..<10_000 {
            buffer.insert(i, at: slot)
            _ = buffer.remove(at: slot)
        }
    }

    // MARK: - Drain

    @Test(.timed(iterations: 20, warmup: 3))
    func `drain 10_000 elements`() {
        var buffer = Buffer<Int>.Slab(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            let slot: Bit.Index = Bit.Index(Ordinal(UInt(i)))
            buffer.insert(i, at: slot)
        }
        var sum = 0
        buffer.drain { sum &+= $0 }
        _ = sum
    }

    // MARK: - Fill and Reset

    @Test(.timed(iterations: 20, warmup: 3))
    func `fill and removeAll 10_000 elements 20 cycles`() {
        var buffer = Buffer<Int>.Slab(minimumCapacity: 10_000)
        for _ in 0..<20 {
            for i in 0..<10_000 {
                let slot: Bit.Index = Bit.Index(Ordinal(UInt(i)))
                buffer.insert(i, at: slot)
            }
            buffer.removeAll()
        }
    }
}
