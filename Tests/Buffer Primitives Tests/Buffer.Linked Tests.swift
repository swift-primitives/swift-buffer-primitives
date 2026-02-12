import Testing
import Buffer_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Linked")
struct LinkedTests {

    @Test
    func `insertFront and removeFront`() throws {
        var buffer = try Buffer<Int>.Linked<2>.create(capacity: 8)
        try buffer.insertFront(10)
        try buffer.insertFront(20)
        try buffer.insertFront(30)

        #expect(buffer.count == 3)

        #expect(buffer.removeFront() == 30)
        #expect(buffer.removeFront() == 20)
        #expect(buffer.removeFront() == 10)
        #expect(buffer.isEmpty)
    }

    @Test
    func `insertBack and removeBack`() throws {
        var buffer = try Buffer<Int>.Linked<2>.create(capacity: 8)
        try buffer.insertBack(10)
        try buffer.insertBack(20)
        try buffer.insertBack(30)

        #expect(buffer.count == 3)

        #expect(buffer.removeBack() == 30)
        #expect(buffer.removeBack() == 20)
        #expect(buffer.removeBack() == 10)
        #expect(buffer.isEmpty)
    }

    @Test
    func `insertFront and removeBack`() throws {
        var buffer = try Buffer<Int>.Linked<2>.create(capacity: 8)
        try buffer.insertFront(10)
        try buffer.insertFront(20)
        try buffer.insertFront(30)

        // Front is 30, 20, 10 — removeBack yields 10, 20, 30
        #expect(buffer.removeBack() == 10)
        #expect(buffer.removeBack() == 20)
        #expect(buffer.removeBack() == 30)
        #expect(buffer.isEmpty)
    }

    @Test
    func `insertBack and removeFront`() throws {
        var buffer = try Buffer<Int>.Linked<2>.create(capacity: 8)
        try buffer.insertBack(10)
        try buffer.insertBack(20)
        try buffer.insertBack(30)

        #expect(buffer.removeFront() == 10)
        #expect(buffer.removeFront() == 20)
        #expect(buffer.removeFront() == 30)
        #expect(buffer.isEmpty)
    }

    @Test
    func `forEach traverses front to back`() throws {
        var buffer = try Buffer<Int>.Linked<2>.create(capacity: 8)
        try buffer.insertBack(10)
        try buffer.insertBack(20)
        try buffer.insertBack(30)

        var collected: [Int] = []
        buffer.forEach { collected.append($0) }
        #expect(collected == [10, 20, 30])
    }

    @Test
    func `forEachReversed traverses back to front`() throws {
        var buffer = try Buffer<Int>.Linked<2>.create(capacity: 8)
        try buffer.insertBack(10)
        try buffer.insertBack(20)
        try buffer.insertBack(30)

        var collected: [Int] = []
        buffer.forEachReversed { collected.append($0) }
        #expect(collected == [30, 20, 10])
    }

    @Test
    func `growth preserves elements`() throws {
        var buffer = try Buffer<Int>.Linked<2>.create(capacity: 2)
        try buffer.insertBack(10)
        try buffer.insertBack(20)
        #expect(buffer.isFull == true)

        // Grow — should preserve existing elements
        try buffer.ensureCapacity(8)
        #expect(buffer.count == 2)

        // Elements survive growth in order
        var collected: [Int] = []
        buffer.forEach { collected.append($0) }
        #expect(collected == [10, 20])

        // Can insert after growth
        try buffer.insertBack(30)
        #expect(buffer.count == 3)
    }

    @Test
    func `ensureUnique on copy`() throws {
        var original = try Buffer<Int>.Linked<2>.create(capacity: 8)
        try original.insertBack(10)
        try original.insertBack(20)
        try original.insertBack(30)

        var copy = original

        // Mutating copy triggers CoW
        let didCopy = copy.ensureUnique()
        #expect(didCopy == true)

        // Second call on unique reference should not copy
        let didCopyAgain = copy.ensureUnique()
        #expect(didCopyAgain == false)
    }

    @Test
    func `copy independence after CoW`() throws {
        var original = try Buffer<Int>.Linked<2>.create(capacity: 8)
        try original.insertBack(10)
        try original.insertBack(20)

        var copy = original
        copy.ensureUnique()
        try copy.insertBack(99)

        // Original unaffected
        #expect(original.count == 2)
        #expect(copy.count == 3)
    }

    @Test
    func `empty list operations`() throws {
        var buffer = try Buffer<Int>.Linked<2>.create(capacity: 4)
        #expect(buffer.isEmpty == true)
        #expect(buffer.count == .zero)
        #expect(buffer.removeFront() == nil)
        #expect(buffer.removeBack() == nil)
    }

    @Test
    func `first and last accessors`() throws {
        var buffer = try Buffer<Int>.Linked<2>.create(capacity: 8)
        #expect(buffer.first == nil)
        #expect(buffer.last == nil)

        try buffer.insertBack(10)
        try buffer.insertBack(20)
        try buffer.insertBack(30)

        #expect(buffer.first == 10)
        #expect(buffer.last == 30)

        // Accessors do not remove
        #expect(buffer.count == 3)
    }

    @Test
    func `Equatable — equal lists`() throws {
        var a = try Buffer<Int>.Linked<2>.create(capacity: 8)
        try a.insertBack(10)
        try a.insertBack(20)
        try a.insertBack(30)

        var b = try Buffer<Int>.Linked<2>.create(capacity: 8)
        try b.insertBack(10)
        try b.insertBack(20)
        try b.insertBack(30)

        #expect(a == b)
    }

    @Test
    func `Equatable — unequal lists`() throws {
        var a = try Buffer<Int>.Linked<2>.create(capacity: 8)
        try a.insertBack(10)
        try a.insertBack(20)

        var b = try Buffer<Int>.Linked<2>.create(capacity: 8)
        try b.insertBack(10)
        try b.insertBack(99)

        #expect(a != b)
    }

    @Test
    func `Equatable — different counts`() throws {
        var a = try Buffer<Int>.Linked<2>.create(capacity: 8)
        try a.insertBack(10)

        var b = try Buffer<Int>.Linked<2>.create(capacity: 8)
        try b.insertBack(10)
        try b.insertBack(20)

        #expect(a != b)
    }

    @Test
    func `Hashable — equal lists produce same hash`() throws {
        var a = try Buffer<Int>.Linked<2>.create(capacity: 8)
        try a.insertBack(10)
        try a.insertBack(20)

        var b = try Buffer<Int>.Linked<2>.create(capacity: 8)
        try b.insertBack(10)
        try b.insertBack(20)

        #expect(a.hashValue == b.hashValue)
    }

    @Test
    func `drain removes all elements in order`() throws {
        var buffer = try Buffer<Int>.Linked<2>.create(capacity: 8)
        try buffer.insertBack(10)
        try buffer.insertBack(20)
        try buffer.insertBack(30)

        var drained: [Int] = []
        buffer.drain { drained.append($0) }
        #expect(drained == [10, 20, 30])
        #expect(buffer.isEmpty)
    }

    @Test
    func `count tracking through insert and remove`() throws {
        var buffer = try Buffer<Int>.Linked<2>.create(capacity: 8)
        #expect(buffer.count == .zero)

        try buffer.insertBack(10)
        #expect(buffer.count == 1)

        try buffer.insertFront(20)
        #expect(buffer.count == 2)

        _ = buffer.removeFront()
        #expect(buffer.count == 1)

        _ = buffer.removeBack()
        #expect(buffer.count == .zero)
    }

    @Test
    func `minimumCapacity init`() {
        let buffer = Buffer<Int>.Linked<2>(
            minimumCapacity: Index<Buffer<Int>.Linked<2>.Node>.Count(UInt(8))
        )
        #expect(buffer.isEmpty == true)
        #expect(buffer.capacity.rawValue.rawValue >= 8)
    }

    @Test
    func `removeAll clears list`() throws {
        var buffer = try Buffer<Int>.Linked<2>.create(capacity: 8)
        try buffer.insertBack(10)
        try buffer.insertBack(20)
        try buffer.insertBack(30)

        buffer.removeAll()

        #expect(buffer.isEmpty == true)
        #expect(buffer.count == .zero)
    }

    @Test
    func `Sequence iteration`() throws {
        var buffer = try Buffer<Int>.Linked<2>.create(capacity: 8)
        try buffer.insertBack(10)
        try buffer.insertBack(20)
        try buffer.insertBack(30)

        var collected: [Int] = []
        var iter = buffer.makeIterator()
        while let value = iter.next() {
            collected.append(value)
        }
        #expect(collected == [10, 20, 30])
    }

    @Test
    func `single element`() throws {
        var buffer = try Buffer<Int>.Linked<2>.create(capacity: 4)
        try buffer.insertBack(42)
        #expect(buffer.count == 1)
        #expect(buffer.first == 42)
        #expect(buffer.last == 42)
        #expect(buffer.removeFront() == 42)
        #expect(buffer.isEmpty)
    }

    @Test
    func `auto grows when full (Copyable)`() throws {
        var buffer = try Buffer<Int>.Linked<2>.create(capacity: 2)
        try buffer.insertBack(10)
        try buffer.insertBack(20)
        #expect(buffer.isFull == true)

        // Copyable variant auto-grows via ensureUnique + _grow
        buffer.insertBack(30)
        #expect(buffer.count == 3)
        #expect(buffer.last == 30)
    }
}

@Suite("Buffer.Linked singly-linked (N=1)")
struct LinkedSinglyTests {

    @Test
    func `insertFront and removeFront`() throws {
        var buffer = try Buffer<Int>.Linked<1>.create(capacity: 8)
        try buffer.insertFront(10)
        try buffer.insertFront(20)
        try buffer.insertFront(30)

        #expect(buffer.removeFront() == 30)
        #expect(buffer.removeFront() == 20)
        #expect(buffer.removeFront() == 10)
        #expect(buffer.isEmpty)
    }

    @Test
    func `insertBack and removeBack — O(n) traversal`() throws {
        var buffer = try Buffer<Int>.Linked<1>.create(capacity: 8)
        try buffer.insertBack(10)
        try buffer.insertBack(20)
        try buffer.insertBack(30)

        // removeBack on singly-linked traverses to find predecessor
        #expect(buffer.removeBack() == 30)
        #expect(buffer.removeBack() == 20)
        #expect(buffer.removeBack() == 10)
        #expect(buffer.isEmpty)
    }

    @Test
    func `forEach traverses front to back`() throws {
        var buffer = try Buffer<Int>.Linked<1>.create(capacity: 8)
        try buffer.insertBack(10)
        try buffer.insertBack(20)
        try buffer.insertBack(30)

        var collected: [Int] = []
        buffer.forEach { collected.append($0) }
        #expect(collected == [10, 20, 30])
    }

    @Test
    func `first and last accessors`() throws {
        var buffer = try Buffer<Int>.Linked<1>.create(capacity: 8)
        try buffer.insertBack(10)
        try buffer.insertBack(20)

        #expect(buffer.first == 10)
        #expect(buffer.last == 20)
    }

    @Test
    func `single element removeBack`() throws {
        var buffer = try Buffer<Int>.Linked<1>.create(capacity: 4)
        try buffer.insertBack(42)

        #expect(buffer.removeBack() == 42)
        #expect(buffer.isEmpty)
    }
}
