import Testing
import Buffer_Slab_Inline_Primitives
import Buffer_Primitives_Test_Support

@Suite(.serialized)
struct `Buffer.Slab.Inline - Performance` {

    // MARK: - Insert Throughput

    @Test(.timed(iterations: 20, warmup: 3))
    func `insert 256 elements`() {
        var buffer = Buffer<Int>.Slab.Inline<256>()
        for i in 0..<256 {
            let slot = Bit.Index.Bounded<256>(Bit.Index(Ordinal(UInt(i))))!
            buffer.insert(i, at: slot)
        }
        buffer.removeAll()
    }

    // MARK: - Remove Throughput

    @Test(.timed(iterations: 20, warmup: 3))
    func `remove 256 elements`() {
        var buffer = Buffer<Int>.Slab.Inline<256>()
        for i in 0..<256 {
            let slot = Bit.Index.Bounded<256>(Bit.Index(Ordinal(UInt(i))))!
            buffer.insert(i, at: slot)
        }
        for i in 0..<256 {
            let slot = Bit.Index.Bounded<256>(Bit.Index(Ordinal(UInt(i))))!
            _ = buffer.remove(at: slot)
        }
    }

    // MARK: - Insert-Remove Cycling

    @Test(.timed(iterations: 20, warmup: 3))
    func `insert-remove 256 cycles at slot 0`() {
        var buffer = Buffer<Int>.Slab.Inline<256>()
        let slot = Bit.Index.Bounded<256>(Bit.Index(Ordinal(UInt(0))))!
        for i in 0..<256 {
            buffer.insert(i, at: slot)
            _ = buffer.remove(at: slot)
        }
    }

    // MARK: - Fill and Reset

    @Test(.timed(iterations: 20, warmup: 3))
    func `fill and removeAll 256 elements 20 cycles`() {
        var buffer = Buffer<Int>.Slab.Inline<256>()
        for _ in 0..<20 {
            for i in 0..<256 {
                let slot = Bit.Index.Bounded<256>(Bit.Index(Ordinal(UInt(i))))!
                buffer.insert(i, at: slot)
            }
            buffer.removeAll()
        }
    }
}
