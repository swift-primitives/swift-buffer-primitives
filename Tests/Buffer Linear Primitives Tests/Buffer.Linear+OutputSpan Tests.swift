import Testing
import Buffer_Linear_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Linear + OutputSpan")
struct LinearOutputSpanTests {
    @Suite struct Init {}
    @Suite struct Append {}
    @Suite struct Edit {}
    @Suite struct NonCopyable {}
    @Suite struct Throwing {}
    @Suite struct CoW {}
}

// MARK: - Test fixtures

fileprivate struct MoveOnly: ~Copyable {
    let value: Int
    init(_ value: Int) { self.value = value }
}

fileprivate enum FixtureError: Swift.Error, Equatable {
    case deliberate
}

// MARK: - Init

extension LinearOutputSpanTests.Init {

    @Test
    func `init with capacity and full population`() throws {
        let buffer = try Buffer<Int>.Linear(capacity: 4) { span in
            span.append(10)
            span.append(20)
            span.append(30)
            span.append(40)
        }
        #expect(buffer.count == 4)
    }

    @Test
    func `init with partial population leaves correct count`() throws {
        let buffer = try Buffer<Int>.Linear(capacity: 8) { span in
            span.append(1)
            span.append(2)
        }
        #expect(buffer.count == 2)
        #expect(buffer.capacity >= 8)
    }

    @Test
    func `init with empty closure`() throws {
        let buffer = try Buffer<Int>.Linear(capacity: 4) { _ in }
        #expect(buffer.isEmpty)
    }

    @Test
    func `init with zero capacity`() throws {
        let buffer = try Buffer<Int>.Linear(capacity: 0) { _ in }
        #expect(buffer.isEmpty)
        #expect(buffer.count == .zero)
    }
}

// MARK: - Append

extension LinearOutputSpanTests.Append {

    @Test
    func `append adds to existing buffer`() throws {
        var buffer = Buffer<Int>.Linear(minimumCapacity: 2)
        buffer.append(1)
        buffer.append(2)

        try buffer.append(addingCapacity: 3) { span in
            span.append(10)
            span.append(20)
            span.append(30)
        }
        #expect(buffer.count == 5)
    }

    @Test
    func `append triggers growth when required exceeds capacity`() throws {
        var buffer = Buffer<Int>.Linear(minimumCapacity: 2)
        buffer.append(1)
        buffer.append(2)
        let capacityBefore = buffer.capacity

        try buffer.append(addingCapacity: 10) { span in
            for i in 0..<10 {
                span.append(100 + i)
            }
        }
        #expect(buffer.count == 12)
        #expect(buffer.capacity >= 12)
        #expect(buffer.capacity > capacityBefore)
    }

    @Test
    func `append with partial population commits what was added`() throws {
        var buffer = Buffer<Int>.Linear(minimumCapacity: 4)
        buffer.append(1)

        try buffer.append(addingCapacity: 5) { span in
            span.append(10)
            span.append(20)
            // Only appends 2, not 5.
        }
        #expect(buffer.count == 3)
    }

    @Test
    func `append with zero addingCapacity is a noop`() throws {
        var buffer = Buffer<Int>.Linear(minimumCapacity: 4)
        buffer.append(1)
        buffer.append(2)

        var capturedCapacity = -1
        var capturedIsFull = false
        try buffer.append(addingCapacity: 0) { span in
            capturedCapacity = span.capacity
            capturedIsFull = span.isFull
        }
        #expect(capturedCapacity == 0)
        #expect(capturedIsFull)
        #expect(buffer.count == 2)
    }
}

// MARK: - Edit

extension LinearOutputSpanTests.Edit {

    @Test
    func `edit can append beyond current count up to capacity`() throws {
        var buffer: Buffer<Int>.Linear = [1, 2, 3]
        buffer.reserveCapacity(10)

        try buffer.edit { span in
            span.append(4)
            span.append(5)
        }
        #expect(buffer.count == 5)
    }

    @Test
    func `edit can remove elements`() throws {
        var buffer: Buffer<Int>.Linear = [1, 2, 3, 4, 5]

        try buffer.edit { span in
            _ = span.removeLast()
            _ = span.removeLast()
        }
        #expect(buffer.count == 3)
    }

    @Test
    func `edit returns the closure result`() throws {
        var buffer: Buffer<Int>.Linear = [1, 2, 3]

        let doubled: Int = try buffer.edit { span in
            return span.count * 2
        }
        #expect(doubled == 6)
    }

    @Test
    func `edit preserves state on throw`() throws {
        var buffer: Buffer<Int>.Linear = [10, 20, 30]
        buffer.reserveCapacity(10)

        do {
            try buffer.edit { span throws(FixtureError) in
                span.append(40)
                span.append(50)
                throw FixtureError.deliberate
            }
            Issue.record("Expected throw")
        } catch FixtureError.deliberate {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        // Elements appended before throw remain committed.
        #expect(buffer.count == 5)
    }
}

// MARK: - NonCopyable

extension LinearOutputSpanTests.NonCopyable {

    @Test
    func `init with noncopyable elements`() throws {
        let buffer = try Buffer<MoveOnly>.Linear(capacity: 3) { span in
            span.append(MoveOnly(1))
            span.append(MoveOnly(2))
            span.append(MoveOnly(3))
        }
        #expect(buffer.count == 3)
    }

    @Test
    func `append with noncopyable elements, triggering growth`() throws {
        var buffer = Buffer<MoveOnly>.Linear(minimumCapacity: 2)
        buffer.append(MoveOnly(1))
        try buffer.append(addingCapacity: 4) { span in
            span.append(MoveOnly(10))
            span.append(MoveOnly(20))
            span.append(MoveOnly(30))
            span.append(MoveOnly(40))
        }
        #expect(buffer.count == 5)
    }
}

// MARK: - Throwing

extension LinearOutputSpanTests.Throwing {

    @Test
    func `init throw destroys partial state and propagates error`() {
        #expect(throws: FixtureError.deliberate) {
            _ = try Buffer<Int>.Linear(capacity: 4) { span throws(FixtureError) in
                span.append(1)
                span.append(2)
                throw FixtureError.deliberate
            }
        }
    }

    @Test
    func `append throw preserves already-initialized elements`() throws {
        var buffer = Buffer<Int>.Linear(minimumCapacity: 2)
        buffer.append(100)

        do {
            try buffer.append(addingCapacity: 5) { span throws(FixtureError) in
                span.append(1)
                span.append(2)
                throw FixtureError.deliberate
            }
            Issue.record("Expected throw")
        } catch FixtureError.deliberate {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        // The two appended-before-throw elements remain; total count = 1 + 2 = 3.
        #expect(buffer.count == 3)
    }

    @Test
    func `init throw with noncopyable elements propagates`() {
        #expect(throws: FixtureError.deliberate) {
            _ = try Buffer<MoveOnly>.Linear(capacity: 3) { span throws(FixtureError) in
                span.append(MoveOnly(1))
                throw FixtureError.deliberate
            }
        }
    }
}

// MARK: - CoW (Copyable elements)

extension LinearOutputSpanTests.CoW {

    @Test
    func `append on shared copy preserves original`() throws {
        var original: Buffer<Int>.Linear = [1, 2, 3]
        var copy = original

        try copy.append(addingCapacity: 2) { span in
            span.append(100)
            span.append(200)
        }

        #expect(copy.count == 5)
        #expect(original.count == 3)  // Original unchanged via CoW
    }
}
