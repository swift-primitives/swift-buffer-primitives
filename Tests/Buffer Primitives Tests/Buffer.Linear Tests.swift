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
        var buffer: Buffer<Int>.Linear = [10, 20, 30]
        var drained: [Int] = []
        buffer.drain { drained.append($0) }
        #expect(drained == [10, 20, 30])
        #expect(buffer.isEmpty)
    }

    @Test
    func `removeAll clears buffer`() {
        var buffer: Buffer<Int>.Linear = [1, 2, 3]
        buffer.removeAll()
        #expect(buffer.isEmpty)
    }

    @Test
    func `peekFront and peekBack (Copyable)`() {
        let buffer: Buffer<Int>.Linear = [10, 20, 30]
        #expect(buffer.peekFront == 10)
        #expect(buffer.peekBack == 30)
    }

    @Test
    func `Sequence.Protocol iteration (Copyable)`() {
        let buffer: Buffer<Int>.Linear = [10, 20, 30]
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

// MARK: - Copy-on-Write

@Suite("Buffer.Linear CoW")
struct LinearCoWTests {

    @Test
    func `copy shares elements initially`() {
        var original: Buffer<Int>.Linear = [1, 2, 3]
        var copy = original

        var originalElements: [Int] = []
        var copyElements: [Int] = []

        original.forEach { originalElements.append($0) }
        copy.forEach { copyElements.append($0) }

        #expect(originalElements == copyElements)
    }

    @Test
    func `append to copy does not affect original`() {
        var original: Buffer<Int>.Linear = [1, 2, 3]
        var copy = original

        copy.append(99)

        #expect(original.count == 3)
        #expect(copy.count == 4)

        #expect(original.peekBack == 3)
        #expect(copy.peekBack == 99)
    }

    @Test
    func `append to original does not affect copy`() {
        var original: Buffer<Int>.Linear = [1, 2, 3]
        var copy = original

        original.append(99)

        #expect(original.count == 4)
        #expect(copy.count == 3)

        #expect(original.peekBack == 99)
        #expect(copy.peekBack == 3)
    }

    @Test
    func `subscript set on copy does not affect original`() {
        var original: Buffer<Int>.Linear = [10, 20, 30]
        var copy = original

        copy[1] = 999

        #expect(original[1] == 20)
        #expect(copy[1] == 999)
    }

    @Test
    func `multiple copies are independent`() {
        var original: Buffer<Int>.Linear = [1, 2]

        var copy1 = original
        var copy2 = original

        copy1.append(100)
        copy2.append(200)
        original.append(300)

        #expect(original.peekBack == 300)
        #expect(copy1.peekBack == 100)
        #expect(copy2.peekBack == 200)

        #expect(original.count == 3)
        #expect(copy1.count == 3)
        #expect(copy2.count == 3)
    }

    @Test
    func `removeLast on copy does not affect original`() {
        var original: Buffer<Int>.Linear = [1, 2, 3]
        var copy = original

        let removed = copy.removeLast()

        #expect(removed == 3)
        #expect(copy.count == 2)
        #expect(original.count == 3)
        #expect(original.peekBack == 3)
    }

    @Test
    func `consumeFront on copy does not affect original`() {
        var original: Buffer<Int>.Linear = [1, 2, 3]
        var copy = original

        let consumed = copy.consumeFront()

        #expect(consumed == 1)
        #expect(copy.count == 2)
        #expect(original.count == 3)
        #expect(original.peekFront == 1)
    }

    @Test
    func `removeAll on copy does not affect original`() {
        var original: Buffer<Int>.Linear = [1, 2, 3]
        var copy = original

        copy.removeAll()

        #expect(copy.isEmpty)
        #expect(original.count == 3)
        #expect(original.peekFront == 1)
        #expect(original.peekBack == 3)
    }

    @Test
    func `reserveCapacity on copy does not affect original`() {
        var original: Buffer<Int>.Linear = [1, 2, 3]
        var copy = original

        copy.reserveCapacity(1000)

        #expect(copy.capacity.rawValue.rawValue >= 1000)
        #expect(original.count == 3)

        // Original elements preserved
        var elements: [Int] = []
        original.forEach { elements.append($0) }
        #expect(elements == [1, 2, 3])
    }
}
