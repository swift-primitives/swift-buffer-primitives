import Testing
import Buffer_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Linear.Header")
struct LinearHeaderTests {

    @Test("init sets count to zero")
    func initDefaults() {
        let cap: Index<Int>.Count = 8
        let header = Buffer<Int>.Linear.Header(capacity: 8)
        #expect(header.count == 0)
        #expect(header.capacity == cap)
    }

    @Test("isEmpty and isFull")
    func emptyAndFull() {
        let cap: Index<Int>.Count = 4
        var header = Buffer<Int>.Linear.Header(capacity: cap)
        #expect(header.isEmpty)
        #expect(!header.isFull)

        header.count = cap
        #expect(!header.isEmpty)
        #expect(header.isFull)
    }

    @Test("initialization is always .empty or .one")
    func initializationAlwaysLinear() {
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
