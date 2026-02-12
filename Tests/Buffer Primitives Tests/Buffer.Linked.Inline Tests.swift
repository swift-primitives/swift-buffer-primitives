import Testing
import Buffer_Primitives
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
    func `insertFront and removeFront`() {
        var buffer = Buffer<Int>.Linked<2>.Inline<8>()
        try! buffer.insertFront(10)
        try! buffer.insertFront(20)
        try! buffer.insertFront(30)

        #expect(buffer.count == 3)

        #expect(buffer.removeFront() == 30)
        #expect(buffer.removeFront() == 20)
        #expect(buffer.removeFront() == 10)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `insertBack and removeBack`() {
        var buffer = Buffer<Int>.Linked<2>.Inline<8>()
        try! buffer.insertBack(10)
        try! buffer.insertBack(20)
        try! buffer.insertBack(30)

        #expect(buffer.removeBack() == 30)
        #expect(buffer.removeBack() == 20)
        #expect(buffer.removeBack() == 10)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `insertBack and removeFront`() {
        var buffer = Buffer<Int>.Linked<2>.Inline<8>()
        try! buffer.insertBack(10)
        try! buffer.insertBack(20)
        try! buffer.insertBack(30)

        #expect(buffer.removeFront() == 10)
        #expect(buffer.removeFront() == 20)
        #expect(buffer.removeFront() == 30)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `capacity overflow throws`() {
        var buffer = Buffer<Int>.Linked<2>.Inline<2>()
        try! buffer.insertBack(10)
        try! buffer.insertBack(20)
        #expect(buffer.isFull == true)

        do {
            try buffer.insertBack(30)
            Issue.record("Expected .capacityExceeded error")
        } catch {
            #expect(error == .capacityExceeded)
        }
    }

    @Test
    func `free-list reuse — insert remove insert reuses slot`() {
        var buffer = Buffer<Int>.Linked<2>.Inline<4>()
        try! buffer.insertBack(10)
        try! buffer.insertBack(20)

        // Remove front to free a slot
        let removed = buffer.removeFront()
        #expect(removed == 10)
        #expect(buffer.count == 1)

        // Insert should reuse the freed slot
        try! buffer.insertBack(30)
        #expect(buffer.count == 2)

        var collected: [Int] = []
        buffer.forEach { collected.append($0) }
        #expect(collected == [20, 30])
    }

    @Test
    func `forEach traverses front to back`() {
        var buffer = Buffer<Int>.Linked<2>.Inline<8>()
        try! buffer.insertBack(10)
        try! buffer.insertBack(20)
        try! buffer.insertBack(30)

        var collected: [Int] = []
        buffer.forEach { collected.append($0) }
        #expect(collected == [10, 20, 30])
    }

    @Test
    func `forEachReversed traverses back to front`() {
        var buffer = Buffer<Int>.Linked<2>.Inline<8>()
        try! buffer.insertBack(10)
        try! buffer.insertBack(20)
        try! buffer.insertBack(30)

        var collected: [Int] = []
        buffer.forEachReversed { collected.append($0) }
        #expect(collected == [30, 20, 10])
    }

    @Test
    func `removeAll clears buffer`() {
        var buffer = Buffer<Int>.Linked<2>.Inline<8>()
        try! buffer.insertBack(10)
        try! buffer.insertBack(20)
        try! buffer.insertBack(30)

        buffer.removeAll()
        #expect(buffer.isEmpty == true)
        #expect(buffer.count == .zero)

        // Can reuse after removeAll
        try! buffer.insertBack(40)
        #expect(buffer.count == 1)
    }

    @Test
    func `first and last accessors`() {
        var buffer = Buffer<Int>.Linked<2>.Inline<8>()
        #expect(buffer.first == nil)
        #expect(buffer.last == nil)

        try! buffer.insertBack(10)
        try! buffer.insertBack(20)
        try! buffer.insertBack(30)

        #expect(buffer.first == 10)
        #expect(buffer.last == 30)

        // Accessors do not remove
        #expect(buffer.count == 3)
    }

    @Test
    func `empty buffer operations`() {
        var buffer = Buffer<Int>.Linked<2>.Inline<4>()
        #expect(buffer.isEmpty == true)
        #expect(buffer.removeFront() == nil)
        #expect(buffer.removeBack() == nil)
    }

    @Test
    func `single element`() {
        var buffer = Buffer<Int>.Linked<2>.Inline<4>()
        try! buffer.insertBack(42)
        #expect(buffer.count == 1)
        #expect(buffer.first == 42)
        #expect(buffer.last == 42)
        #expect(buffer.removeFront() == 42)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `fill to capacity then drain`() {
        var buffer = Buffer<Int>.Linked<2>.Inline<4>()
        try! buffer.insertBack(10)
        try! buffer.insertBack(20)
        try! buffer.insertBack(30)
        try! buffer.insertBack(40)
        #expect(buffer.isFull == true)

        #expect(buffer.removeFront() == 10)
        #expect(buffer.removeFront() == 20)
        #expect(buffer.removeFront() == 30)
        #expect(buffer.removeFront() == 40)
        #expect(buffer.isEmpty == true)
    }
}
