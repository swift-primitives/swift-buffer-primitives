import Testing
import Buffer_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Linear.Bounded")
struct LinearBoundedTests {

    @Test
    func `init creates empty bounded buffer`() {
        let buffer = Buffer<Int>.Linear.Bounded(minimumCapacity: 4)
        #expect(buffer.isEmpty == true)
        #expect(buffer.count == .zero)
        #expect(buffer.isFull == false)
    }

    @Test
    func `append and removeLast`() {
        var buffer = Buffer<Int>.Linear.Bounded(minimumCapacity: 4)
        _ = buffer.append(10)
        _ = buffer.append(20)
        _ = buffer.append(30)

        #expect(buffer.removeLast() == 30)
        #expect(buffer.removeLast() == 20)
        #expect(buffer.removeLast() == 10)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `append and removeFirst`() {
        var buffer = Buffer<Int>.Linear.Bounded(minimumCapacity: 4)
        _ = buffer.append(10)
        _ = buffer.append(20)
        _ = buffer.append(30)

        #expect(buffer.removeFirst() == 10)
        #expect(buffer.removeFirst() == 20)
        #expect(buffer.removeFirst() == 30)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `removeAll clears buffer`() {
        var buffer = Buffer<Int>.Linear.Bounded(minimumCapacity: 4)
        _ = buffer.append(1)
        _ = buffer.append(2)
        _ = buffer.append(3)
        buffer.removeAll()
        #expect(buffer.isEmpty == true)
        #expect(buffer.count == .zero)
    }

    @Test
    func `isFull detection`() {
        var buffer = Buffer<Int>.Linear.Bounded(minimumCapacity: 2)
        #expect(buffer.isFull == false)

        let cap = buffer.capacity.rawValue.rawValue
        var i: UInt = 0
        while i < cap {
            _ = buffer.append(Int(i))
            i += 1
        }
        #expect(buffer.isFull == true)
    }

    @Test
    func `append returns element when full`() {
        var buffer = Buffer<Int>.Linear.Bounded(minimumCapacity: 2)
        let cap = buffer.capacity.rawValue.rawValue
        var i: UInt = 0
        while i < cap {
            let rejected = buffer.append(Int(i))
            #expect(rejected == nil)
            i += 1
        }
        #expect(buffer.isFull == true)

        let rejected = buffer.append(999)
        #expect(rejected == 999)
    }

    @Test
    func `subscript access`() {
        var buffer = Buffer<Int>.Linear.Bounded(minimumCapacity: 4)
        _ = buffer.append(10)
        _ = buffer.append(20)
        _ = buffer.append(30)

        #expect(buffer[Index<Int>(Ordinal(UInt(0)))] == 10)
        #expect(buffer[Index<Int>(Ordinal(UInt(1)))] == 20)
        #expect(buffer[Index<Int>(Ordinal(UInt(2)))] == 30)

        buffer[Index<Int>(Ordinal(UInt(1)))] = 999
        #expect(buffer[Index<Int>(Ordinal(UInt(1)))] == 999)
    }

    @Test
    func `peekFront and peekBack`() {
        var buffer = Buffer<Int>.Linear.Bounded(minimumCapacity: 4)
        _ = buffer.append(10)
        _ = buffer.append(20)
        _ = buffer.append(30)

        #expect(buffer.peekFront == 10)
        #expect(buffer.peekBack == 30)
        #expect(buffer.count == 3)
    }

    @Test
    func `ensureUnique copies shared storage`() {
        var buffer = Buffer<Int>.Linear.Bounded(minimumCapacity: 4)
        _ = buffer.append(10)
        _ = buffer.append(20)

        var copy = buffer
        let didCopy = copy.ensureUnique()
        #expect(didCopy == true)

        let secondCall = copy.ensureUnique()
        #expect(secondCall == false)
    }

    @Test
    func `CoW — append to copy does not affect original`() {
        var original = Buffer<Int>.Linear.Bounded(minimumCapacity: 4)
        _ = original.append(1)
        _ = original.append(2)

        var copy = original
        _ = copy.append(99)

        #expect(original.count == 2)
        #expect(copy.count == 3)
        #expect(original.peekBack == 2)
        #expect(copy.peekBack == 99)
    }

    @Test
    func `CoW — removeLast on copy does not affect original`() {
        var original = Buffer<Int>.Linear.Bounded(minimumCapacity: 4)
        _ = original.append(1)
        _ = original.append(2)
        _ = original.append(3)

        var copy = original
        let removed = copy.removeLast()

        #expect(removed == 3)
        #expect(copy.count == 2)
        #expect(original.count == 3)
        #expect(original.peekBack == 3)
    }

    @Test
    func `drain removes all in front-to-back order`() {
        var buffer = Buffer<Int>.Linear.Bounded(minimumCapacity: 8)
        _ = buffer.append(10)
        _ = buffer.append(20)
        _ = buffer.append(30)

        var drained: [Int] = []
        buffer.drain { drained.append($0) }
        #expect(drained == [10, 20, 30])
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `single element`() {
        var buffer = Buffer<Int>.Linear.Bounded(minimumCapacity: 1)
        let rejected = buffer.append(42)
        #expect(rejected == nil)
        #expect(buffer.count == 1)
        #expect(buffer.removeLast() == 42)
        #expect(buffer.isEmpty == true)
    }
}
