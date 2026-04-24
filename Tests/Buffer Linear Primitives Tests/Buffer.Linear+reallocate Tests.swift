import Testing
import Buffer_Linear_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Linear reallocate")
struct LinearReallocateTests {

    @Test
    func `reallocate can grow`() {
        var buffer: Buffer<Int>.Linear = [1, 2, 3]
        let initial = buffer.capacity
        buffer.reallocate(capacity: 100)
        #expect(buffer.capacity >= 100)
        #expect(buffer.capacity > initial)
        #expect(buffer.count == 3)
    }

    @Test
    func `reallocate can shrink`() {
        var buffer: Buffer<Int>.Linear = []
        buffer.reserveCapacity(100)
        buffer.append(1)
        buffer.append(2)
        let beforeShrink = buffer.capacity
        buffer.reallocate(capacity: 5)
        #expect(buffer.count == 2)
        #expect(buffer.capacity < beforeShrink)
        #expect(buffer.capacity >= 2)
    }

    @Test
    func `reallocate preserves existing elements on grow`() {
        var buffer: Buffer<Int>.Linear = [10, 20, 30]
        buffer.reallocate(capacity: 50)
        #expect(buffer.count == 3)
        // Elements should still be accessible (span-based read)
        #expect(buffer.span.count == 3)
    }

    @Test
    func `reallocate preserves existing elements on shrink`() {
        var buffer: Buffer<Int>.Linear = []
        buffer.reserveCapacity(100)
        buffer.append(42)
        buffer.append(43)
        buffer.reallocate(capacity: 2)
        #expect(buffer.count == 2)
        #expect(buffer.span.count == 2)
    }

    @Test
    func `reallocate to capacity equal to count`() {
        var buffer: Buffer<Int>.Linear = [1, 2, 3]
        buffer.reserveCapacity(100)
        buffer.reallocate(capacity: 3)
        #expect(buffer.count == 3)
        #expect(buffer.capacity >= 3)
    }

    @Test
    func `reallocate on CoW-shared buffer does not affect original`() {
        var original: Buffer<Int>.Linear = [1, 2, 3]
        original.reserveCapacity(50)
        let originalCap = original.capacity

        var copy = original
        copy.reallocate(capacity: 10)

        #expect(copy.count == 3)
        #expect(copy.capacity < originalCap)
        #expect(original.count == 3)
        #expect(original.capacity == originalCap)
    }
}
