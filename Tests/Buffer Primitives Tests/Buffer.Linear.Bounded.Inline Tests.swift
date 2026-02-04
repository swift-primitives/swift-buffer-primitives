import Testing
import Buffer_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Linear.Bounded.Inline")
struct LinearBoundedInlineTests {

    @Test("append and consumeFront")
    func appendConsumeFront() throws {
        var buffer = try Buffer.Linear.Bounded<Int>.Inline<4>()
        _ = buffer.append(10)
        _ = buffer.append(20)
        _ = buffer.append(30)

        #expect(buffer.count == 3)

        #expect(buffer.consumeFront() == 10)
        #expect(buffer.consumeFront() == 20)
        #expect(buffer.consumeFront() == 30)
        #expect(buffer.isEmpty)
    }

    @Test("append and removeLast")
    func appendRemoveLast() throws {
        var buffer = try Buffer.Linear.Bounded<Int>.Inline<4>()
        _ = buffer.append(10)
        _ = buffer.append(20)
        _ = buffer.append(30)

        #expect(buffer.removeLast() == 30)
        #expect(buffer.removeLast() == 20)
        #expect(buffer.removeLast() == 10)
        #expect(buffer.isEmpty)
    }

    @Test("full rejection — append returns element when full")
    func fullRejection() throws {
        var buffer = try Buffer.Linear.Bounded<Int>.Inline<4>()

        _ = buffer.append(0)
        _ = buffer.append(1)
        _ = buffer.append(2)
        _ = buffer.append(3)
        #expect(buffer.isFull)

        let rejected = buffer.append(999)
        #expect(rejected == 999)
    }

    @Test("peekFront and peekBack (Copyable)")
    func peekFrontBack() throws {
        let buffer = try Buffer.Linear.Bounded<Int>.Inline<8>.with([10, 20, 30])
        #expect(buffer.peekFront == 10)
        #expect(buffer.peekBack == 30)
        #expect(buffer.count == 3)
    }

    @Test("drain removes all elements in front-to-back order")
    func drain() throws {
        var buffer = try Buffer.Linear.Bounded<Int>.Inline<8>.with([10, 20, 30])
        var drained: [Int] = []
        buffer.drain { drained.append($0) }
        #expect(drained == [10, 20, 30])
        #expect(buffer.isEmpty)
    }

    @Test("removeAll clears buffer")
    func removeAll() throws {
        var buffer = try Buffer.Linear.Bounded<Int>.Inline<8>.with([1, 2, 3])
        buffer.removeAll()
        #expect(buffer.isEmpty)
        #expect(buffer.count == 0)
    }

    @Test("Sequence.Protocol iteration (Copyable)")
    func sequenceIteration() throws {
        let buffer = try Buffer.Linear.Bounded<Int>.Inline<8>.with([10, 20, 30])
        var collected: [Int] = []
        var iter = buffer.makeIterator()
        while let value = iter.next() {
            collected.append(value)
        }
        #expect(collected == [10, 20, 30])
    }

    @Test("single element")
    func singleElement() throws {
        var buffer = try Buffer.Linear.Bounded<Int>.Inline<1>()
        _ = buffer.append(42)
        #expect(buffer.count == 1)
        #expect(buffer.isFull)
        #expect(buffer.consumeFront() == 42)
        #expect(buffer.isEmpty)
    }
}
