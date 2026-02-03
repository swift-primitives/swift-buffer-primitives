import Testing
import Buffer_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Linear Static Operations")
struct LinearStaticTests {

    @Test("append increments count and stores element")
    func appendBasic() {
        let cap: Index<Storage>.Count = 8
        var header = Buffer.Linear.Header(capacity: cap)
        let storage = Storage.Heap<Int>.create(minimumCapacity: cap)

        Buffer.Linear.append(10, header: &header, storage: storage)
        Buffer.Linear.append(20, header: &header, storage: storage)

        #expect(header.count == 2)

        // Verify storage contents via consumeBack
        let b = Buffer.Linear.consumeBack(header: &header, storage: storage)
        let a = Buffer.Linear.consumeBack(header: &header, storage: storage)
        #expect(a == 10)
        #expect(b == 20)

        storage.initialization = .empty
    }

    @Test("consumeFront removes first and shifts")
    func consumeFrontShifts() {
        let cap: Index<Storage>.Count = 8
        var header = Buffer.Linear.Header(capacity: cap)
        let storage = Storage.Heap<Int>.create(minimumCapacity: cap)

        Buffer.Linear.append(10, header: &header, storage: storage)
        Buffer.Linear.append(20, header: &header, storage: storage)
        Buffer.Linear.append(30, header: &header, storage: storage)

        let first = Buffer.Linear.consumeFront(header: &header, storage: storage)
        #expect(first == 10)
        #expect(header.count == 2)

        let second = Buffer.Linear.consumeFront(header: &header, storage: storage)
        #expect(second == 20)

        let third = Buffer.Linear.consumeFront(header: &header, storage: storage)
        #expect(third == 30)

        #expect(header.isEmpty)
        storage.initialization = .empty
    }

    @Test("consumeBack removes last element")
    func consumeBack() {
        let cap: Index<Storage>.Count = 8
        var header = Buffer.Linear.Header(capacity: cap)
        let storage = Storage.Heap<Int>.create(minimumCapacity: cap)

        Buffer.Linear.append(10, header: &header, storage: storage)
        Buffer.Linear.append(20, header: &header, storage: storage)

        let last = Buffer.Linear.consumeBack(header: &header, storage: storage)
        #expect(last == 20)
        #expect(header.count == 1)

        let first = Buffer.Linear.consumeBack(header: &header, storage: storage)
        #expect(first == 10)
        #expect(header.isEmpty)

        storage.initialization = .empty
    }

    @Test("deinitializeAll clears everything")
    func deinitializeAll() {
        let cap: Index<Storage>.Count = 8
        var header = Buffer.Linear.Header(capacity: cap)
        let storage = Storage.Heap<Int>.create(minimumCapacity: cap)

        Buffer.Linear.append(1, header: &header, storage: storage)
        Buffer.Linear.append(2, header: &header, storage: storage)
        Buffer.Linear.append(3, header: &header, storage: storage)

        Buffer.Linear.deinitializeAll(header: &header, storage: storage)

        #expect(header.isEmpty)
    }

    @Test("initialization stays .one for linear")
    func initializationTracking() {
        let cap: Index<Storage>.Count = 8
        var header = Buffer.Linear.Header(capacity: cap)
        let storage = Storage.Heap<Int>.create(minimumCapacity: cap)

        #expect(header.initialization == .empty)

        Buffer.Linear.append(42, header: &header, storage: storage)
        switch header.initialization {
        case .one(let range):
            #expect(range.lowerBound == 0)
            #expect(range.upperBound == 1)
        default:
            Issue.record("Expected .one")
        }

        Buffer.Linear.deinitializeAll(header: &header, storage: storage)
    }
}
