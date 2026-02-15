import Testing
import Buffer_Linked_Inline_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Linked.Inline")
struct LinkedInlineTests {

    @Test
    func `init creates empty buffer`() {
        let buffer = Buffer<Int>.Linked<2>.Inline<8>()
        #expect(buffer.isEmpty == true)
        #expect(buffer.count == .zero)
    }

    @Test
    func `insert.front and remove.front`() {
        var buffer = Buffer<Int>.Linked<2>.Inline<8>()
        try! buffer.insert.front(10)
        try! buffer.insert.front(20)
        try! buffer.insert.front(30)

        #expect(buffer.count == 3)

        #expect(buffer.remove.front() == 30)
        #expect(buffer.remove.front() == 20)
        #expect(buffer.remove.front() == 10)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `insert.back and remove.back`() {
        var buffer = Buffer<Int>.Linked<2>.Inline<8>()
        try! buffer.insert.back(10)
        try! buffer.insert.back(20)
        try! buffer.insert.back(30)

        #expect(buffer.remove.back() == 30)
        #expect(buffer.remove.back() == 20)
        #expect(buffer.remove.back() == 10)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `insert.back and remove.front`() {
        var buffer = Buffer<Int>.Linked<2>.Inline<8>()
        try! buffer.insert.back(10)
        try! buffer.insert.back(20)
        try! buffer.insert.back(30)

        #expect(buffer.remove.front() == 10)
        #expect(buffer.remove.front() == 20)
        #expect(buffer.remove.front() == 30)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `capacity overflow throws`() {
        var buffer = Buffer<Int>.Linked<2>.Inline<2>()
        try! buffer.insert.back(10)
        try! buffer.insert.back(20)
        #expect(buffer.isFull == true)

        do {
            try buffer.insert.back(30)
            Issue.record("Expected .capacityExceeded error")
        } catch {
            #expect(error == .capacityExceeded)
        }
    }

    @Test
    func `free-list reuse — insert remove insert reuses slot`() {
        var buffer = Buffer<Int>.Linked<2>.Inline<4>()
        try! buffer.insert.back(10)
        try! buffer.insert.back(20)

        // Remove front to free a slot
        let removed = buffer.remove.front()
        #expect(removed == 10)
        #expect(buffer.count == 1)

        // Insert should reuse the freed slot
        try! buffer.insert.back(30)
        #expect(buffer.count == 2)

        var collected: [Int] = []
        buffer.forEach { collected.append($0) }
        #expect(collected == [20, 30])
    }

    @Test
    func `forEach traverses front to back`() {
        var buffer = Buffer<Int>.Linked<2>.Inline<8>()
        try! buffer.insert.back(10)
        try! buffer.insert.back(20)
        try! buffer.insert.back(30)

        var collected: [Int] = []
        buffer.forEach { collected.append($0) }
        #expect(collected == [10, 20, 30])
    }

    @Test
    func `forEachReversed traverses back to front`() {
        var buffer = Buffer<Int>.Linked<2>.Inline<8>()
        try! buffer.insert.back(10)
        try! buffer.insert.back(20)
        try! buffer.insert.back(30)

        var collected: [Int] = []
        buffer.forEachReversed { collected.append($0) }
        #expect(collected == [30, 20, 10])
    }

    @Test
    func `removeAll clears buffer`() {
        var buffer = Buffer<Int>.Linked<2>.Inline<8>()
        try! buffer.insert.back(10)
        try! buffer.insert.back(20)
        try! buffer.insert.back(30)

        buffer.removeAll()
        #expect(buffer.isEmpty == true)
        #expect(buffer.count == .zero)

        // Can reuse after removeAll
        try! buffer.insert.back(40)
        #expect(buffer.count == 1)
    }

    @Test
    func `first and last accessors`() {
        var buffer = Buffer<Int>.Linked<2>.Inline<8>()
        #expect(buffer.first == nil)
        #expect(buffer.last == nil)

        try! buffer.insert.back(10)
        try! buffer.insert.back(20)
        try! buffer.insert.back(30)

        #expect(buffer.first == 10)
        #expect(buffer.last == 30)

        // Accessors do not remove
        #expect(buffer.count == 3)
    }

    @Test
    func `empty buffer operations`() {
        var buffer = Buffer<Int>.Linked<2>.Inline<4>()
        #expect(buffer.isEmpty == true)
        #expect(buffer.remove.front() == nil)
        #expect(buffer.remove.back() == nil)
    }

    @Test
    func `single element`() {
        var buffer = Buffer<Int>.Linked<2>.Inline<4>()
        try! buffer.insert.back(42)
        #expect(buffer.count == 1)
        #expect(buffer.first == 42)
        #expect(buffer.last == 42)
        #expect(buffer.remove.front() == 42)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `fill to capacity then drain`() {
        var buffer = Buffer<Int>.Linked<2>.Inline<4>()
        try! buffer.insert.back(10)
        try! buffer.insert.back(20)
        try! buffer.insert.back(30)
        try! buffer.insert.back(40)
        #expect(buffer.isFull == true)

        #expect(buffer.remove.front() == 10)
        #expect(buffer.remove.front() == 20)
        #expect(buffer.remove.front() == 30)
        #expect(buffer.remove.front() == 40)
        #expect(buffer.isEmpty == true)
    }
}
