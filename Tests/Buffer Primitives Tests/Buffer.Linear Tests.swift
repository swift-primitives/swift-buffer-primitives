import Testing
import Buffer_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Linear")
struct LinearGrowableTests {

    @Test
    func `append and consumeFront`() {
        var buffer = Buffer<Int>.Linear(minimumCapacity: 4)
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)

        #expect(buffer.consumeFront() == 10)
        #expect(buffer.consumeFront() == 20)
        #expect(buffer.consumeFront() == 30)
        #expect(buffer.isEmpty)
    }

    @Test
    func `append and removeLast`() {
        var buffer = Buffer<Int>.Linear(minimumCapacity: 4)
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)

        #expect(buffer.removeLast() == 30)
        #expect(buffer.removeLast() == 20)
        #expect(buffer.removeLast() == 10)
        #expect(buffer.isEmpty)
    }

    @Test
    func `growth doubles capacity`() {
        var buffer = Buffer<Int>.Linear(minimumCapacity: 2)
        let originalCap = buffer.capacity

        var i = 0
        let needed = Int(originalCap.rawValue.rawValue) + 1
        while i < needed {
            buffer.append(i * 10)
            i += 1
        }

        #expect(buffer.capacity.rawValue.rawValue > originalCap.rawValue.rawValue)

        // Verify elements survived growth
        i = 0
        while i < needed {
            #expect(buffer.consumeFront() == i * 10)
            i += 1
        }
    }

    @Test
    func `drain removes all in front-to-back order`() {
        var buffer = Buffer<Int>.Linear.with([10, 20, 30])
        var drained: [Int] = []
        buffer.drain { drained.append($0) }
        #expect(drained == [10, 20, 30])
        #expect(buffer.isEmpty)
    }

    @Test
    func `removeAll clears buffer`() {
        var buffer = Buffer<Int>.Linear.with([1, 2, 3])
        buffer.removeAll()
        #expect(buffer.isEmpty)
    }

    @Test
    func `peekFront and peekBack (Copyable)`() {
        let buffer = Buffer<Int>.Linear.with([10, 20, 30])
        #expect(buffer.peekFront == 10)
        #expect(buffer.peekBack == 30)
    }

    @Test
    func `Sequence.Protocol iteration (Copyable)`() {
        let buffer = Buffer<Int>.Linear.with([10, 20, 30])
        var collected: [Int] = []
        var iter = buffer.makeIterator()
        while let value = iter.next() {
            collected.append(value)
        }
        #expect(collected == [10, 20, 30])
    }

    @Test
    func `single element`() {
        var buffer = Buffer<Int>.Linear(minimumCapacity: 1)
        buffer.append(42)
        #expect(buffer.count == 1)
        #expect(buffer.removeLast() == 42)
        #expect(buffer.isEmpty)
    }

    @Test
    func `reserveCapacity grows if needed`() {
        var buffer = Buffer<Int>.Linear(minimumCapacity: 2)
        buffer.reserveCapacity(100)
        #expect(buffer.capacity.rawValue.rawValue >= 100)
    }
}
