import Testing
import Buffer_Linear_Inline_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Linear.Inline")
struct LinearBoundedInlineTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
}

// MARK: - Unit

extension LinearBoundedInlineTests.Unit {

    @Test
    func `append and removeFirst`() throws {
        var buffer = Buffer<Int>.Linear.Inline<4>()
        _ = buffer.append(10)
        _ = buffer.append(20)
        _ = buffer.append(30)

        #expect(buffer.count == 3)

        #expect(buffer.removeFirst() == 10)
        #expect(buffer.removeFirst() == 20)
        #expect(buffer.removeFirst() == 30)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `append and removeLast`() throws {
        var buffer = Buffer<Int>.Linear.Inline<4>()
        _ = buffer.append(10)
        _ = buffer.append(20)
        _ = buffer.append(30)

        #expect(buffer.removeLast() == 30)
        #expect(buffer.removeLast() == 20)
        #expect(buffer.removeLast() == 10)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `peekFront and peekBack (Copyable)`() throws {
        let buffer = try Buffer<Int>.Linear.Inline<8>([10, 20, 30])
        #expect(buffer.peekFront == 10)
        #expect(buffer.peekBack == 30)
        #expect(buffer.count == 3)
    }

    @Test
    func `drain removes all elements in front-to-back order`() throws {
        var buffer = try Buffer<Int>.Linear.Inline<8>([10, 20, 30])
        var drained: [Int] = []
        buffer.drain { drained.append($0) }
        #expect(drained == [10, 20, 30])
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `removeAll clears buffer`() throws {
        var buffer = try Buffer<Int>.Linear.Inline<8>([1, 2, 3])
        buffer.removeAll()
        #expect(buffer.isEmpty == true)
        #expect(buffer.count == 0)
    }

    @Test
    func `Sequence.Protocol iteration (Copyable)`() throws {
        let buffer = try Buffer<Int>.Linear.Inline<8>([10, 20, 30])
        var collected: [Int] = []
        var iter = buffer.makeIterator()
        while let value = iter.next() {
            collected.append(value)
        }
        #expect(collected == [10, 20, 30])
    }

    @Test
    func `single element`() throws {
        var buffer = Buffer<Int>.Linear.Inline<1>()
        _ = buffer.append(42)
        #expect(buffer.count == 1)
        #expect(buffer.isFull == true)
        #expect(buffer.removeFirst() == 42)
        #expect(buffer.isEmpty == true)
    }
}

// MARK: - Edge Cases

extension LinearBoundedInlineTests.EdgeCase {

    @Test
    func `full rejection — append returns element when full`() throws {
        var buffer = Buffer<Int>.Linear.Inline<4>()

        _ = buffer.append(0)
        _ = buffer.append(1)
        _ = buffer.append(2)
        _ = buffer.append(3)
        #expect(buffer.isFull == true)

        let rejected = buffer.append(999)
        #expect(rejected == 999)
    }

    @Test
    func `removeAll then reuse`() throws {
        var buffer = Buffer<Int>.Linear.Inline<4>()
        _ = buffer.append(10)
        _ = buffer.append(20)
        buffer.removeAll()
        #expect(buffer.isEmpty == true)

        _ = buffer.append(30)
        #expect(buffer.count == 1)
        #expect(buffer.peekFront == 30)
    }
}

// MARK: - Integration

extension LinearBoundedInlineTests.Integration {

    @Test
    func `fill then drain cycle`() throws {
        var buffer = Buffer<Int>.Linear.Inline<4>()
        _ = buffer.append(10)
        _ = buffer.append(20)
        _ = buffer.append(30)
        _ = buffer.append(40)
        #expect(buffer.isFull == true)

        var drained: [Int] = []
        buffer.drain { drained.append($0) }
        #expect(drained == [10, 20, 30, 40])
        #expect(buffer.isEmpty == true)
    }
}
