import Testing
import Buffer_Linear_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Linear.Bounded + OutputSpan")
struct LinearBoundedOutputSpanTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct NonCopyable {}
    @Suite struct Throwing {}
}

// MARK: - Test fixtures

/// Move-only element used to verify that the OutputSpan-based init works with ~Copyable elements.
fileprivate struct MoveOnly: ~Copyable {
    let value: Int
    init(_ value: Int) { self.value = value }
}

fileprivate enum FixtureError: Swift.Error, Equatable {
    case deliberate
}

// MARK: - Unit (Copyable elements)

extension LinearBoundedOutputSpanTests.Unit {

    @Test
    func `init fills the OutputSpan exactly`() throws {
        // Note: storage.slotCapacity may exceed the requested `capacity`;
        // the OutputSpan is sized exactly to `capacity` (matches stdlib semantics).
        let buffer = try Buffer<Int>.Linear.Bounded(capacity: 4) { span in
            span.append(10)
            span.append(20)
            span.append(30)
            span.append(40)
        }
        #expect(buffer.count == 4)
        #expect(buffer.capacity >= 4)
    }

    @Test
    func `init with partial population leaves correct count`() throws {
        let buffer = try Buffer<Int>.Linear.Bounded(capacity: 8) { span in
            span.append(1)
            span.append(2)
            span.append(3)
        }
        #expect(buffer.count == 3)
        #expect(buffer.capacity >= 8)
        #expect(buffer.isFull == false)
    }

    @Test
    func `init with empty closure yields empty buffer`() throws {
        let buffer = try Buffer<Int>.Linear.Bounded(capacity: 4) { _ in }
        #expect(buffer.isEmpty == true)
        #expect(buffer.count == .zero)
        #expect(buffer.capacity >= 4)
    }

    @Test
    func `init with zero capacity`() throws {
        let buffer = try Buffer<Int>.Linear.Bounded(capacity: 0) { _ in }
        #expect(buffer.isEmpty == true)
        #expect(buffer.count == .zero)
    }
}

// MARK: - EdgeCase

extension LinearBoundedOutputSpanTests.EdgeCase {

    @Test
    func `OutputSpan freeCapacity decreases with appends`() throws {
        var captured: [Int] = []
        let buffer = try Buffer<Int>.Linear.Bounded(capacity: 3) { span in
            captured.append(span.freeCapacity)  // 3
            span.append(100)
            captured.append(span.freeCapacity)  // 2
            span.append(200)
            captured.append(span.freeCapacity)  // 1
        }
        #expect(captured == [3, 2, 1])
        #expect(buffer.count == 2)
    }

    @Test
    func `OutputSpan isFull reflects requested capacity`() throws {
        var fullAtEnd: Bool = false
        let buffer = try Buffer<Int>.Linear.Bounded(capacity: 2) { span in
            span.append(1)
            span.append(2)
            fullAtEnd = span.isFull
        }
        #expect(fullAtEnd == true)  // OutputSpan is sized to requested capacity
        #expect(buffer.count == 2)   // All requested slots populated
    }
}

// MARK: - NonCopyable (~Copyable elements)

extension LinearBoundedOutputSpanTests.NonCopyable {

    @Test
    func `init with noncopyable elements`() throws {
        let buffer = try Buffer<MoveOnly>.Linear.Bounded(capacity: 3) { span in
            span.append(MoveOnly(1))
            span.append(MoveOnly(2))
            span.append(MoveOnly(3))
        }
        #expect(buffer.count == 3)
    }

    @Test
    func `init partial-populate with noncopyable elements`() throws {
        let buffer = try Buffer<MoveOnly>.Linear.Bounded(capacity: 5) { span in
            span.append(MoveOnly(42))
        }
        #expect(buffer.count == 1)
        #expect(buffer.capacity == 5)
    }
}

// MARK: - Throwing

extension LinearBoundedOutputSpanTests.Throwing {

    @Test
    func `init throws propagates the error`() {
        #expect(throws: FixtureError.deliberate) {
            _ = try Buffer<Int>.Linear.Bounded(capacity: 4) { span throws(FixtureError) in
                span.append(1)
                span.append(2)
                throw FixtureError.deliberate
            }
        }
    }

    @Test
    func `init throws with noncopyable elements — elements cleaned up`() {
        // If this test leaks, ASan or debug allocators will catch it.
        // Behaviourally we just verify the throw propagates.
        #expect(throws: FixtureError.deliberate) {
            _ = try Buffer<MoveOnly>.Linear.Bounded(capacity: 3) { span throws(FixtureError) in
                span.append(MoveOnly(1))
                span.append(MoveOnly(2))
                throw FixtureError.deliberate
            }
        }
    }
}
