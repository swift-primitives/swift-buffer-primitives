import Testing
import Buffer_Ring_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Ring.Header")
struct RingHeaderTests {

    @Test
    func `init sets head to zero, count to zero`() {
        let cap: Index<Int>.Count = 8
        let header = Buffer<Int>.Ring.Header(capacity: cap)
        #expect(header.head == 0)
        #expect(header.count == 0)
        #expect(header.capacity == cap)
    }

    @Test
    func `isEmpty and isFull`() {
        let cap: Index<Int>.Count = 4
        var header = Buffer<Int>.Ring.Header(capacity: cap)
        #expect(header.isEmpty)
        #expect(!header.isFull)

        header.count = cap
        #expect(!header.isEmpty)
        #expect(header.isFull)
    }

    @Test
    func `initialization returns .empty when count is zero`() {
        let header = Buffer<Int>.Ring.Header(capacity: 4)
        switch header.initialization {
        case .empty:
            break
        default:
            Issue.record("Expected .empty, got \(header.initialization)")
        }
    }

    @Test
    func `initialization returns .one for non-wrapping elements`() {
        var header = Buffer<Int>.Ring.Header(capacity: 8)
        header.count = 3
        // head=0, count=3, capacity=8 → .one(0..<3)
        switch header.initialization {
        case .one(let range):
            #expect(range.lowerBound == 0)
            #expect(range.upperBound == 3)
        default:
            Issue.record("Expected .one, got \(header.initialization)")
        }
    }

    @Test
    func `initialization returns .two for wrapping elements`() {
        var header = Buffer<Int>.Ring.Header(capacity: 4)
        header.head = 3
        header.count = 3
        // head=3, count=3, capacity=4 → wraps: first=[3,4), second=[0,2)
        switch header.initialization {
        case .two(let first, let second):
            #expect(first.lowerBound == 3)
            #expect(first.upperBound == 4)
            #expect(second.lowerBound == 0)
            #expect(second.upperBound == 2)
        default:
            Issue.record("Expected .two, got \(header.initialization)")
        }
    }

    @Test
    func `Copyable`() {
        let a = Buffer<Int>.Ring.Header(capacity: 4)
        let b = a
        #expect(b.head == a.head)
        #expect(b.count == a.count)
        #expect(b.capacity == a.capacity)
    }
}
