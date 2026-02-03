import Testing
import Buffer_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Ring.Header")
struct RingHeaderTests {

    @Test("init sets head to zero, count to zero")
    func initDefaults() {
        let cap: Index<Storage>.Count = 8
        let header = Buffer.Ring.Header(capacity: cap)
        #expect(header.head == 0)
        #expect(header.count == 0)
        #expect(header.capacity == cap)
    }

    @Test("isEmpty and isFull")
    func emptyAndFull() {
        let cap: Index<Storage>.Count = 4
        var header = Buffer.Ring.Header(capacity: cap)
        #expect(header.isEmpty)
        #expect(!header.isFull)

        header.count = cap
        #expect(!header.isEmpty)
        #expect(header.isFull)
    }

    @Test("initialization returns .empty when count is zero")
    func initializationEmpty() {
        let header = Buffer.Ring.Header(capacity: 4)
        switch header.initialization {
        case .empty:
            break
        default:
            Issue.record("Expected .empty, got \(header.initialization)")
        }
    }

    @Test("initialization returns .one for non-wrapping elements")
    func initializationOne() {
        var header = Buffer.Ring.Header(capacity: 8)
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

    @Test("initialization returns .two for wrapping elements")
    func initializationTwo() {
        var header = Buffer.Ring.Header(capacity: 4)
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

    @Test("Copyable and Hashable")
    func copyableHashable() {
        let a = Buffer.Ring.Header(capacity: 4)
        let b = a
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }
}
