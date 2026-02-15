import Testing
import Buffer_Ring_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Ring Static Operations")
struct RingStaticTests {

    @Test
    func `pushBack/popFront FIFO ordering`() {
        let cap: Index<Int>.Count = 4
        var header = Buffer<Int>.Ring.Header(capacity: cap)
        let storage = Storage<Int>.Heap.create(minimumCapacity: cap)

        Buffer<Int>.Ring.pushBack(10, header: &header, storage: storage)
        Buffer<Int>.Ring.pushBack(20, header: &header, storage: storage)
        Buffer<Int>.Ring.pushBack(30, header: &header, storage: storage)

        #expect(header.count == 3)

        let a = Buffer<Int>.Ring.popFront(header: &header, storage: storage)
        let b = Buffer<Int>.Ring.popFront(header: &header, storage: storage)
        let c = Buffer<Int>.Ring.popFront(header: &header, storage: storage)

        #expect(a == 10)
        #expect(b == 20)
        #expect(c == 30)
        #expect(header.isEmpty)

        storage.initialization = .empty
    }

    @Test
    func `pushFront/popBack ordering`() {
        let cap: Index<Int>.Count = 4
        var header = Buffer<Int>.Ring.Header(capacity: cap)
        let storage = Storage<Int>.Heap.create(minimumCapacity: cap)

        Buffer<Int>.Ring.pushFront(10, header: &header, storage: storage)
        Buffer<Int>.Ring.pushFront(20, header: &header, storage: storage)

        let a = Buffer<Int>.Ring.popBack(header: &header, storage: storage)
        let b = Buffer<Int>.Ring.popBack(header: &header, storage: storage)

        #expect(a == 10)
        #expect(b == 20)
        #expect(header.isEmpty)

        storage.initialization = .empty
    }

    @Test
    func `wrap-around correctness`() {
        let cap: Index<Int>.Count = 4
        var header = Buffer<Int>.Ring.Header(capacity: cap)
        let storage = Storage<Int>.Heap.create(minimumCapacity: cap)

        // Fill to capacity
        var i = 0
        while i < 4 {
            Buffer<Int>.Ring.pushBack(i, header: &header, storage: storage)
            i += 1
        }
        #expect(header.isFull)

        // Pop two from front
        _ = Buffer<Int>.Ring.popFront(header: &header, storage: storage)
        _ = Buffer<Int>.Ring.popFront(header: &header, storage: storage)

        // Push two more — these wrap around
        Buffer<Int>.Ring.pushBack(100, header: &header, storage: storage)
        Buffer<Int>.Ring.pushBack(200, header: &header, storage: storage)

        // Should read: 2, 3, 100, 200
        let a = Buffer<Int>.Ring.popFront(header: &header, storage: storage)
        let b = Buffer<Int>.Ring.popFront(header: &header, storage: storage)
        let c = Buffer<Int>.Ring.popFront(header: &header, storage: storage)
        let d = Buffer<Int>.Ring.popFront(header: &header, storage: storage)

        #expect(a == 2)
        #expect(b == 3)
        #expect(c == 100)
        #expect(d == 200)

        storage.initialization = .empty
    }

    @Test
    func `physicalSlot logical-to-physical mapping`() {
        var header = Buffer<Int>.Ring.Header(capacity: 8)
        header.head = 5
        header.count = 4

        // Logical 0 → physical 5
        let p0 = Buffer<Int>.Ring.physicalSlot(forLogical: 0, header: header)
        #expect(p0 == 5)

        // Logical 3 → physical (5+3)%8 = 0
        let p3 = Buffer<Int>.Ring.physicalSlot(forLogical: 3, header: header)
        #expect(p3 == 0)
    }

    @Test
    func `initialization sync through operations`() {
        let cap: Index<Int>.Count = 4
        var header = Buffer<Int>.Ring.Header(capacity: cap)
        let storage = Storage<Int>.Heap.create(minimumCapacity: cap)

        // Start empty
        #expect(header.initialization == .empty)

        // Push one → .one
        Buffer<Int>.Ring.pushBack(42, header: &header, storage: storage)
        switch header.initialization {
        case .one: break
        default: Issue.record("Expected .one")
        }

        // Fill capacity, advance head to force wrap
        Buffer<Int>.Ring.pushBack(43, header: &header, storage: storage)
        Buffer<Int>.Ring.pushBack(44, header: &header, storage: storage)
        _ = Buffer<Int>.Ring.popFront(header: &header, storage: storage)
        _ = Buffer<Int>.Ring.popFront(header: &header, storage: storage)
        Buffer<Int>.Ring.pushBack(45, header: &header, storage: storage)
        Buffer<Int>.Ring.pushBack(46, header: &header, storage: storage)

        // Should be wrapping → .two
        switch header.initialization {
        case .two: break
        default: Issue.record("Expected .two for wrapped state")
        }

        // Drain all → .empty
        Buffer<Int>.Ring.deinitializeAll(header: &header, storage: storage)
        #expect(header.initialization == .empty)
    }

    @Test
    func `deinitializeAll clears everything`() {
        let cap: Index<Int>.Count = 4
        var header = Buffer<Int>.Ring.Header(capacity: cap)
        let storage = Storage<Int>.Heap.create(minimumCapacity: cap)

        Buffer<Int>.Ring.pushBack(1, header: &header, storage: storage)
        Buffer<Int>.Ring.pushBack(2, header: &header, storage: storage)

        Buffer<Int>.Ring.deinitializeAll(header: &header, storage: storage)

        #expect(header.isEmpty)
        #expect(header.head == 0)
    }
}
