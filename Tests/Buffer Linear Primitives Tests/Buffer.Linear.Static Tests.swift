import Testing
import Buffer_Linear_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Linear Static Operations")
struct LinearStaticTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
}

// MARK: - Unit

extension LinearStaticTests.Unit {

    @Test
    func `append increments count and stores element`() {
        let cap: Index<Int>.Count = 8
        var header = Buffer<Int>.Linear.Header(capacity: cap)
        let storage = Storage<Int>.Heap.create(minimumCapacity: cap)

        Buffer<Int>.Linear.append(10, header: &header, storage: storage)
        Buffer<Int>.Linear.append(20, header: &header, storage: storage)

        #expect(header.count == 2)

        // Verify storage contents via consumeBack
        let b = Buffer<Int>.Linear.consumeBack(header: &header, storage: storage)
        let a = Buffer<Int>.Linear.consumeBack(header: &header, storage: storage)
        #expect(a == 10)
        #expect(b == 20)

        storage.initialization = .empty
    }

    @Test
    func `removeFirst removes first and shifts`() {
        let cap: Index<Int>.Count = 8
        var header = Buffer<Int>.Linear.Header(capacity: cap)
        let storage = Storage<Int>.Heap.create(minimumCapacity: cap)

        Buffer<Int>.Linear.append(10, header: &header, storage: storage)
        Buffer<Int>.Linear.append(20, header: &header, storage: storage)
        Buffer<Int>.Linear.append(30, header: &header, storage: storage)

        let first = Buffer<Int>.Linear.removeFirst(header: &header, storage: storage)
        #expect(first == 10)
        #expect(header.count == 2)

        let second = Buffer<Int>.Linear.removeFirst(header: &header, storage: storage)
        #expect(second == 20)

        let third = Buffer<Int>.Linear.removeFirst(header: &header, storage: storage)
        #expect(third == 30)

        #expect(header.isEmpty)
        storage.initialization = .empty
    }

    @Test
    func `consumeBack removes last element`() {
        let cap: Index<Int>.Count = 8
        var header = Buffer<Int>.Linear.Header(capacity: cap)
        let storage = Storage<Int>.Heap.create(minimumCapacity: cap)

        Buffer<Int>.Linear.append(10, header: &header, storage: storage)
        Buffer<Int>.Linear.append(20, header: &header, storage: storage)

        let last = Buffer<Int>.Linear.consumeBack(header: &header, storage: storage)
        #expect(last == 20)
        #expect(header.count == 1)

        let first = Buffer<Int>.Linear.consumeBack(header: &header, storage: storage)
        #expect(first == 10)
        #expect(header.isEmpty)

        storage.initialization = .empty
    }

    @Test
    func `deinitializeAll clears everything`() {
        let cap: Index<Int>.Count = 8
        var header = Buffer<Int>.Linear.Header(capacity: cap)
        let storage = Storage<Int>.Heap.create(minimumCapacity: cap)

        Buffer<Int>.Linear.append(1, header: &header, storage: storage)
        Buffer<Int>.Linear.append(2, header: &header, storage: storage)
        Buffer<Int>.Linear.append(3, header: &header, storage: storage)

        Buffer<Int>.Linear.deinitializeAll(header: &header, storage: storage)

        #expect(header.isEmpty)
    }

    @Test
    func `initialization stays .one for linear`() {
        let cap: Index<Int>.Count = 8
        var header = Buffer<Int>.Linear.Header(capacity: cap)
        let storage = Storage<Int>.Heap.create(minimumCapacity: cap)

        #expect(header.initialization == .empty)

        Buffer<Int>.Linear.append(42, header: &header, storage: storage)
        switch header.initialization {
        case .one(let range):
            #expect(range.lowerBound == 0)
            #expect(range.upperBound == 1)
        default:
            Issue.record("Expected .one")
        }

        Buffer<Int>.Linear.deinitializeAll(header: &header, storage: storage)
    }
}

// MARK: - Edge Cases

extension LinearStaticTests.EdgeCase {

    @Test
    func `append then consumeBack round-trips single element`() {
        let cap: Index<Int>.Count = 4
        var header = Buffer<Int>.Linear.Header(capacity: cap)
        let storage = Storage<Int>.Heap.create(minimumCapacity: cap)

        Buffer<Int>.Linear.append(42, header: &header, storage: storage)
        let v = Buffer<Int>.Linear.consumeBack(header: &header, storage: storage)
        #expect(v == 42)
        #expect(header.isEmpty)

        storage.initialization = .empty
    }
}
