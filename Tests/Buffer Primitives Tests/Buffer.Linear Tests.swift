import Testing
import Buffer_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Linear")
struct LinearGrowableTests {

    @Test("append and consumeFront")
    func appendConsumeFront() {
        var buffer = Buffer<Int>.Linear(minimumCapacity: 4)
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)

        #expect(buffer.consumeFront() == 10)
        #expect(buffer.consumeFront() == 20)
        #expect(buffer.consumeFront() == 30)
        #expect(buffer.isEmpty)
    }

    @Test("append and removeLast")
    func appendRemoveLast() {
        var buffer = Buffer<Int>.Linear(minimumCapacity: 4)
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)

        #expect(buffer.removeLast() == 30)
        #expect(buffer.removeLast() == 20)
        #expect(buffer.removeLast() == 10)
        #expect(buffer.isEmpty)
    }

    @Test("growth doubles capacity")
    func growth() {
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

    @Test("drain removes all in front-to-back order")
    func drain() {
        var buffer = Buffer<Int>.Linear.with([10, 20, 30])
        var drained: [Int] = []
        buffer.drain { drained.append($0) }
        #expect(drained == [10, 20, 30])
        #expect(buffer.isEmpty)
    }

    @Test("removeAll clears buffer")
    func removeAll() {
        var buffer = Buffer<Int>.Linear.with([1, 2, 3])
        buffer.removeAll()
        #expect(buffer.isEmpty)
    }

    @Test("peekFront and peekBack (Copyable)")
    func peekFrontBack() {
        let buffer = Buffer<Int>.Linear.with([10, 20, 30])
        #expect(buffer.peekFront == 10)
        #expect(buffer.peekBack == 30)
    }

    @Test("Sequence.Protocol iteration (Copyable)")
    func sequenceIteration() {
        let buffer = Buffer<Int>.Linear.with([10, 20, 30])
        var collected: [Int] = []
        var iter = buffer.makeIterator()
        while let value = iter.next() {
            collected.append(value)
        }
        #expect(collected == [10, 20, 30])
    }

    @Test("single element")
    func singleElement() {
        var buffer = Buffer<Int>.Linear(minimumCapacity: 1)
        buffer.append(42)
        #expect(buffer.count == 1)
        #expect(buffer.removeLast() == 42)
        #expect(buffer.isEmpty)
    }

    @Test("reserveCapacity grows if needed")
    func reserveCapacity() {
        var buffer = Buffer<Int>.Linear(minimumCapacity: 2)
        buffer.reserveCapacity(100)
        #expect(buffer.capacity.rawValue.rawValue >= 100)
    }
}
