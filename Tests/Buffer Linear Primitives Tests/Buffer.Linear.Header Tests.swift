import Testing
import Buffer_Linear_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Linear.Header")
struct LinearHeaderTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
}

// MARK: - Unit

extension LinearHeaderTests.Unit {

    @Test
    func `init sets count to zero`() {
        let cap: Index<Int>.Count = 8
        let header = Buffer<Int>.Linear.Header(capacity: 8)
        #expect(header.count == 0)
        #expect(header.capacity == cap)
    }

    @Test
    func `isEmpty and isFull`() {
        let cap: Index<Int>.Count = 4
        var header = Buffer<Int>.Linear.Header(capacity: cap)
        #expect(header.isEmpty)
        #expect(!header.isFull)

        header.count = cap
        #expect(!header.isEmpty)
        #expect(header.isFull)
    }

    @Test
    func `initialization is always .empty or .one`() {
        var header = Buffer<Int>.Linear.Header(capacity: 8)

        switch header.initialization {
        case .empty:
            break
        default:
            Issue.record("Expected .empty")
        }

        header.count = 5
        switch header.initialization {
        case .one(let range):
            #expect(range.lowerBound == 0)
            #expect(range.upperBound == 5)
        default:
            Issue.record("Expected .one(0..<5)")
        }
    }
}

// MARK: - Edge Cases

extension LinearHeaderTests.EdgeCase {

    @Test
    func `initialization linearize — always starts from zero`() {
        var header = Buffer<Int>.Linear.Header(capacity: 8)
        header.count = 3
        // Linear buffers always start from offset 0
        switch header.initialization {
        case .one(let range):
            #expect(range.lowerBound == 0)
            #expect(range.upperBound == 3)
        default:
            Issue.record("Expected .one")
        }
    }

    @Test
    func `full header initialization covers entire capacity`() {
        var header = Buffer<Int>.Linear.Header(capacity: 4)
        header.count = 4
        switch header.initialization {
        case .one(let range):
            #expect(range.lowerBound == 0)
            #expect(range.upperBound == 4)
        default:
            Issue.record("Expected .one(0..<4)")
        }
    }
}
