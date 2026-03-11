import Testing
import Buffer_Slots_Primitives
import Buffer_Primitives_Test_Support

@Suite(.serialized)
struct `Buffer.Slots - Performance` {

    // MARK: - Initialize Throughput

    @Test(.timed(iterations: 20, warmup: 3))
    func `initialize 10_000 elements`() {
        var buffer = Buffer<Int>.Slots<UInt8>(capacity: 10_000, metadataInitial: 0)
        for i in 0..<10_000 {
            let slot = Index<Int>(Ordinal(UInt(i)))
            buffer.initialize(to: i, at: slot)
            buffer[metadata: slot] = 1
        }
        buffer.deinitialize { $0 != 0 }
    }

    // MARK: - Read Throughput

    @Test(.timed(iterations: 20, warmup: 3))
    func `subscript read 10_000 elements`() {
        var buffer = Buffer<Int>.Slots<UInt8>(capacity: 10_000, metadataInitial: 0)
        for i in 0..<10_000 {
            let slot = Index<Int>(Ordinal(UInt(i)))
            buffer.initialize(to: i, at: slot)
            buffer[metadata: slot] = 1
        }
        var sum = 0
        for i in 0..<10_000 {
            let slot = Index<Int>(Ordinal(UInt(i)))
            sum &+= buffer[payload: slot]
        }
        _ = sum
        buffer.deinitialize { $0 != 0 }
    }

    // MARK: - Move Throughput

    @Test(.timed(iterations: 20, warmup: 3))
    func `move 10_000 elements`() {
        var buffer = Buffer<Int>.Slots<UInt8>(capacity: 10_000, metadataInitial: 0)
        for i in 0..<10_000 {
            let slot = Index<Int>(Ordinal(UInt(i)))
            buffer.initialize(to: i, at: slot)
            buffer[metadata: slot] = 1
        }
        for i in 0..<10_000 {
            let slot = Index<Int>(Ordinal(UInt(i)))
            _ = buffer.move(at: slot)
            buffer[metadata: slot] = 0
        }
    }

    // MARK: - Metadata Fill

    @Test(.timed(iterations: 20, warmup: 3))
    func `fill metadata 10_000 slots`() {
        let buffer = Buffer<Int>.Slots<UInt8>(capacity: 10_000, metadataInitial: 0)
        buffer.fill(metadata: 0xFF)
        _ = buffer.capacity
    }

    // MARK: - Initialize-Move Cycling

    @Test(.timed(iterations: 20, warmup: 3))
    func `initialize-move 10_000 cycles at slot 0`() {
        let buffer = Buffer<Int>.Slots<UInt8>(capacity: 100, metadataInitial: 0)
        let slot = Index<Int>(Ordinal(UInt(0)))
        for i in 0..<10_000 {
            buffer.initialize(to: i, at: slot)
            _ = buffer.move(at: slot)
        }
    }
}
