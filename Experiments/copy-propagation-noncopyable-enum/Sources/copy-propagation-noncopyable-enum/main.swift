// MARK: - CopyPropagation Crash: ~Copyable Enum Payload Consumption
// Purpose: Reproduce CopyPropagation SIL pass crash (signal 6) in release builds
//          when consuming ~Copyable values inside enum switch cases.
//
// Two distinct patterns trigger the crash in production (buffer-primitives):
//   Pattern A: Consuming a ~Copyable parameter inside switch on @frozen ~Copyable enum
//              — two consuming operations (element + enum payload) in one branch
//   Pattern B: Conditionally moving ~Copyable elements in a loop with bitmap checks
//              — CopyPropagation can't model conditional ownership in loops
//
// Variants tested:
//   V1: Concrete type, flat struct                    — DOES NOT CRASH
//   V2: Generic <Element: ~Copyable>, flat struct     — DOES NOT CRASH
//   V3: Nested in generic enum namespace              — DOES NOT CRASH
//   V4: Value generic <let capacity: Int> + nested    — DOES NOT CRASH
//   V5: Slab with value generic + bitmap              — DOES NOT CRASH
//
// Conclusion: Context-sensitive bug per [EXP-004a]. Requires the full production
//             codebase interaction (5+ layers of @inlinable typed infrastructure
//             cascading through cross-module generic specialization). The experiment
//             proves no single factor causes the crash — only their interaction does.
//
// Toolchain: Xcode 26.0 beta 2 (Swift 6.2)
// Platform: macOS 26.0 (arm64)
//
// Result: REFUTED — crash does not reproduce in isolation
// Date: 2026-02-15

import StorageLib

// ============================================================================
// MARK: - V3: Nested in generic enum namespace (matches Buffer<Element> pattern)
// ============================================================================

public enum Container<Element: ~Copyable> {

    @frozen
    public struct Inline: ~Copyable {
        public var storage: InlineStorage<Element>
        public var count: Int

        @inlinable
        public init(capacity: Int) {
            self.storage = InlineStorage(capacity: capacity)
            self.count = 0
        }

        @inlinable
        public mutating func append(_ element: consuming Element) {
            storage.initialize(to: consume element, at: count)
            count += 1
        }

        @inlinable
        public func move(at index: Int) -> Element {
            storage.move(at: index)
        }
    }

    @frozen
    public struct Small: ~Copyable {
        @frozen
        public enum _Representation: ~Copyable {
            case inline(Inline)
            case heap(HeapStorage<Element>)
        }

        public var _storage: _Representation

        @inlinable
        public init(capacity: Int) {
            self._storage = .inline(Inline(capacity: capacity))
        }

        @inlinable
        init(_storage: consuming _Representation) {
            self._storage = consume _storage
        }

        @inlinable
        public mutating func append(_ element: consuming Element) {
            switch _storage {
            case .inline(var buf):
                if buf.count < buf.storage.capacity {
                    buf.append(element)
                    self = Small(_storage: .inline(consume buf))
                } else {
                    let heap = HeapStorage<Element>(capacity: buf.storage.capacity * 2)
                    for i in 0..<buf.count {
                        heap.append(buf.move(at: i))
                    }
                    self = Small(_storage: .heap(heap))
                    _appendToHeap(element)
                }
            case .heap(var heap):
                heap.append(element)
                self = Small(_storage: .heap(consume heap))
            }
        }

        @inlinable
        public mutating func _appendToHeap(_ element: consuming Element) {
            switch _storage {
            case .inline(var buf):
                self = Small(_storage: .inline(consume buf))
                fatalError("Expected heap")
            case .heap(var heap):
                heap.append(element)
                self = Small(_storage: .heap(consume heap))
            }
        }
    }
}

extension Container.Inline: @unchecked Sendable where Element: Sendable {}
extension Container.Small: @unchecked Sendable where Element: Sendable {}

// ============================================================================
// MARK: - V4: Value generic + nested (matches Buffer<Element>.Linear.Small<capacity>)
// ============================================================================

public enum VContainer<Element: ~Copyable> {

    @frozen
    public struct Small<let capacity: Int>: ~Copyable {
        @frozen
        public enum _Representation: ~Copyable {
            case inline(InlineStorage<Element>)
            case heap(HeapStorage<Element>)
        }

        public var _storage: _Representation
        public var count: Int

        @inlinable
        public init() {
            self._storage = .inline(InlineStorage(capacity: capacity))
            self.count = 0
        }

        @inlinable
        init(_storage: consuming _Representation, count: Int) {
            self._storage = consume _storage
            self.count = count
        }

        @inlinable
        public mutating func append(_ element: consuming Element) {
            switch _storage {
            case .inline(var buf):
                if count < capacity {
                    buf.initialize(to: consume element, at: count)
                    self = Small(_storage: .inline(consume buf), count: count + 1)
                } else {
                    let heap = HeapStorage<Element>(capacity: capacity * 2)
                    for i in 0..<count {
                        heap.append(buf.move(at: i))
                    }
                    self = Small(_storage: .heap(heap), count: count)
                    _appendToHeap(element)
                }
            case .heap(var heap):
                heap.append(element)
                self = Small(_storage: .heap(consume heap), count: count + 1)
            }
        }

        @inlinable
        public mutating func _appendToHeap(_ element: consuming Element) {
            switch _storage {
            case .inline(var buf):
                self = Small(_storage: .inline(consume buf), count: count)
                fatalError("Expected heap")
            case .heap(var heap):
                heap.append(element)
                self = Small(_storage: .heap(consume heap), count: count + 1)
            }
        }
    }
}

extension VContainer.Small: @unchecked Sendable where Element: Sendable {}

// ============================================================================
// MARK: - V5: Slab with value generic (matches Buffer.Slab.Inline<wordCount>)
// ============================================================================

public enum SlabContainer<Element: ~Copyable> {

    @frozen
    public struct Inline<let wordCount: Int>: ~Copyable {
        public var storage: InlineStorage<Element>
        public var bitmap: UInt64

        @inlinable
        public init() {
            self.storage = InlineStorage(capacity: wordCount)
            self.bitmap = 0
        }

        @inlinable
        public func isOccupied(_ index: Int) -> Bool {
            (bitmap >> index) & 1 == 1
        }

        @inlinable
        public mutating func insert(_ element: consuming Element, at index: Int) {
            storage.initialize(to: element, at: index)
            bitmap |= (1 << index)
        }

        @inlinable
        public mutating func removeAll() {
            for i in 0..<wordCount {
                if isOccupied(i) {
                    storage.deinitialize(at: i)
                    bitmap &= ~(1 << i)
                }
            }
        }

        @inlinable
        public mutating func drain(_ body: (consuming Element) -> Void) {
            for i in 0..<wordCount {
                if isOccupied(i) {
                    let element = storage.move(at: i)
                    bitmap &= ~(1 << i)
                    body(consume element)
                }
            }
        }

        @inlinable
        public mutating func consume() -> HeapStorage<Element> {
            let heap = HeapStorage<Element>(capacity: wordCount)
            for i in 0..<wordCount {
                if isOccupied(i) {
                    let element = storage.move(at: i)
                    bitmap &= ~(1 << i)
                    heap.append(element)
                }
            }
            return heap
        }

        deinit {
            for i in 0..<wordCount {
                if isOccupied(i) {
                    storage.deinitialize(at: i)
                }
            }
        }
    }
}

extension SlabContainer.Inline: @unchecked Sendable where Element: Sendable {}

// ============================================================================
// MARK: - Instantiation
// ============================================================================

func testV3() {
    var buf = Container<NCElement>.Small(capacity: 2)
    buf.append(NCElement(1))
    buf.append(NCElement(2))
    buf.append(NCElement(3))
    print("V3 (nested generic): OK")
}

func testV4() {
    var buf = VContainer<NCElement>.Small<2>()
    buf.append(NCElement(1))
    buf.append(NCElement(2))
    buf.append(NCElement(3))
    print("V4 (value generic): OK")
}

func testV5_removeAll() {
    var slab = SlabContainer<NCElement>.Inline<8>()
    slab.insert(NCElement(10), at: 0)
    slab.insert(NCElement(20), at: 3)
    slab.insert(NCElement(30), at: 7)
    slab.removeAll()
    print("V5 removeAll: OK")
}

func testV5_drain() {
    var slab = SlabContainer<NCElement>.Inline<8>()
    slab.insert(NCElement(10), at: 0)
    slab.insert(NCElement(20), at: 3)
    slab.insert(NCElement(30), at: 7)
    slab.drain { element in
        print("  drained: \(element.value)")
    }
    print("V5 drain: OK")
}

func testV5_consume() {
    var slab = SlabContainer<NCElement>.Inline<8>()
    slab.insert(NCElement(10), at: 0)
    slab.insert(NCElement(20), at: 3)
    slab.insert(NCElement(30), at: 7)
    let _ = slab.consume()
    print("V5 consume: OK")
}

testV3()
testV4()
testV5_removeAll()
testV5_drain()
testV5_consume()
