// MARK: - V13: Real Storage.Inline from storage-primitives
// Purpose: Test if the ACTUAL Storage.Inline library triggers the LLVM
//          verifier crash when consumed as a stored field cross-module.
// Hypothesis: The real library's typed infrastructure (Tagged, Ordinal,
//             Cardinal, Bit.Vector.Static, Property.View) creates enough
//             complexity for the optimizer to generate broken IR.
//
// Toolchain: Xcode 26.0 beta 2 (Swift 6.2)
// Platform: macOS 26.0 (arm64)
//
// Result: (pending)
// Date: 2026-02-15

import Storage_Inline_Primitives

// ============================================================================
// MARK: - V13a: Struct with real Storage.Inline, no deinit
// ============================================================================

struct V13a<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var header: Int
    var storage: Storage<Element>.Inline<capacity>

    init(header: Int, storage: consuming Storage<Element>.Inline<capacity>) {
        self.header = header
        self.storage = storage
    }
}

// ============================================================================
// MARK: - V13b: Same + empty deinit
// ============================================================================

struct V13b<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var header: Int
    var storage: Storage<Element>.Inline<capacity>

    init(header: Int, storage: consuming Storage<Element>.Inline<capacity>) {
        self.header = header
        self.storage = storage
    }

    deinit {}
}

// ============================================================================
// MARK: - V13c: Same + deinit calling cleanup
// ============================================================================

struct V13c<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var header: Int
    var storage: Storage<Element>.Inline<capacity>

    init(header: Int, storage: consuming Storage<Element>.Inline<capacity>) {
        self.header = header
        self.storage = storage
    }

    deinit {
        unsafe storage._deinitializeTrackedSlots()
    }
}

// ============================================================================
// MARK: - V13d: Nested inside generic enum (exact Buffer<Element> pattern)
// ============================================================================

enum Container<Element: ~Copyable> {
    struct Inline<let capacity: Int>: ~Copyable {
        var header: Int
        var storage: Storage<Element>.Inline<capacity>

        init(header: Int, storage: consuming Storage<Element>.Inline<capacity>) {
            self.header = header
            self.storage = storage
        }
    }

    struct InlineWithDeinit<let capacity: Int>: ~Copyable {
        var header: Int
        var storage: Storage<Element>.Inline<capacity>

        init(header: Int, storage: consuming Storage<Element>.Inline<capacity>) {
            self.header = header
            self.storage = storage
        }

        deinit {
            unsafe storage._deinitializeTrackedSlots()
        }
    }
}

// ============================================================================
// MARK: - Conditional conformances (matches production)
// ============================================================================

extension V13a: Sendable where Element: Sendable {}
extension V13b: Sendable where Element: Sendable {}
extension V13c: Sendable where Element: Sendable {}
extension Container.Inline: Sendable where Element: Sendable {}
extension Container.InlineWithDeinit: Sendable where Element: Sendable {}

// ============================================================================
// MARK: - V28: Real Storage.Inline + ManagedBuffer (the actual production pattern)
// Hypothesis: The LLVM verifier crash requires real @_rawLayout (from storage-
//             primitives) cross-module + ManagedBuffer class reference.
// ============================================================================

final class HeapBuf: ManagedBuffer<Int, Int> {
    static func make(capacity: Int) -> HeapBuf {
        let buf = HeapBuf.create(minimumCapacity: capacity) { _ in 0 }
        return unsafe unsafeDowncast(buf, to: HeapBuf.self)
    }
}

/// Wraps ManagedBuffer to mimic Buffer<Element>.Ring structure.
struct HeapWrap<Element: ~Copyable>: ~Copyable, @unchecked Sendable {
    var count: Int
    var storage: HeapBuf

    @inlinable
    init(capacity: Int) {
        self.count = 0
        self.storage = HeapBuf.make(capacity: capacity)
    }
}

// V28a: Storage.Inline + ManagedBuffer class directly (nil)
struct V28a<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var inline: Storage<Element>.Inline<capacity>
    var heap: HeapBuf?

    init() {
        self.inline = Storage<Element>.Inline<capacity>()
        self.heap = nil
    }
}

// V28b: Storage.Inline + ManagedBuffer class directly (active)
struct V28b<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var inline: Storage<Element>.Inline<capacity>
    var heap: HeapBuf?

    init() {
        self.inline = Storage<Element>.Inline<capacity>()
        self.heap = HeapBuf.make(capacity: 8)
    }
}

// V28c: Storage.Inline + HeapWrap (closest to production Small)
struct V28c<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var inline: Storage<Element>.Inline<capacity>
    var heap: HeapWrap<Element>?

    init() {
        self.inline = Storage<Element>.Inline<capacity>()
        self.heap = nil
    }
}

// V28d: Same but with heap active
struct V28d<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var inline: Storage<Element>.Inline<capacity>
    var heap: HeapWrap<Element>?

    init(withHeap: Bool) {
        self.inline = Storage<Element>.Inline<capacity>()
        self.heap = withHeap ? HeapWrap(capacity: 8) : nil
    }
}

// V28e: Nested in generic enum (exact production nesting)
extension Container {
    struct Small<let capacity: Int>: ~Copyable {
        var inline: Storage<Element>.Inline<capacity>
        var heap: HeapWrap<Element>?

        init() {
            self.inline = Storage<Element>.Inline<capacity>()
            self.heap = nil
        }
    }
}

extension Container.Small: Sendable where Element: Sendable {}

// ============================================================================
// MARK: - V29: @frozen variants (production uses @frozen)
// The @frozen attribute changes SIL/IR generation significantly —
// may be required to trigger the dominance violation.
// ============================================================================

@frozen
public struct V29a<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var inline: Storage<Element>.Inline<capacity>
    var heap: HeapBuf?

    init() {
        self.inline = Storage<Element>.Inline<capacity>()
        self.heap = nil
    }
}

@frozen
public struct V29b<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var inline: Storage<Element>.Inline<capacity>
    var heap: HeapWrap<Element>?

    init() {
        self.inline = Storage<Element>.Inline<capacity>()
        self.heap = nil
    }
}

@frozen
public struct V29c<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var inline: Storage<Element>.Inline<capacity>
    var heap: HeapWrap<Element>?

    init() {
        self.inline = Storage<Element>.Inline<capacity>()
        self.heap = HeapWrap(capacity: capacity * 2)
    }
}

// V30: @frozen with @inlinable init and actual mutation methods
@frozen
public struct V30<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var inline: Storage<Element>.Inline<capacity>
    var heap: HeapWrap<Element>?

    @inlinable
    init() {
        self.inline = Storage<Element>.Inline<capacity>()
        self.heap = nil
    }

    @inlinable
    var isSpilled: Bool { heap != nil }

    @inlinable
    mutating func spill() {
        guard heap == nil else { return }
        heap = HeapWrap(capacity: capacity * 2)
    }
}

// ============================================================================
// MARK: - Instantiation (force specialization)
// ============================================================================

func testV13() {
    do {
        let storage = Storage<Int>.Inline<8>()
        let _ = V13a<Int, 8>(header: 42, storage: storage)
        print("V13a (real Storage.Inline, no deinit): OK")
    }
    do {
        let storage = Storage<Int>.Inline<8>()
        let _ = V13b<Int, 8>(header: 42, storage: storage)
        print("V13b (real Storage.Inline, empty deinit): OK")
    }
    do {
        let storage = Storage<Int>.Inline<8>()
        let _ = V13c<Int, 8>(header: 42, storage: storage)
        print("V13c (real Storage.Inline, deinit cleanup): OK")
    }
    do {
        let storage = Storage<Int>.Inline<8>()
        let _ = Container<Int>.Inline<8>(header: 42, storage: storage)
        print("V13d (nested, no deinit): OK")
    }
    do {
        let storage = Storage<Int>.Inline<8>()
        let _ = Container<Int>.InlineWithDeinit<8>(header: 42, storage: storage)
        print("V13e (nested, deinit cleanup): OK")
    }
    // V28: Real Storage.Inline + ManagedBuffer
    do {
        let _ = V28a<Int, 8>()
        print("V28a (Storage.Inline + HeapBuf?, nil): OK")
    }
    do {
        let _ = V28b<Int, 8>()
        print("V28b (Storage.Inline + HeapBuf?, active): OK")
    }
    do {
        let _ = V28c<Int, 8>()
        print("V28c (Storage.Inline + HeapWrap?, nil): OK")
    }
    do {
        let _ = V28d<Int, 8>(withHeap: false)
        print("V28d (Storage.Inline + HeapWrap?, nil): OK")
    }
    do {
        let _ = V28d<Int, 8>(withHeap: true)
        print("V28d (Storage.Inline + HeapWrap?, active): OK")
    }
    do {
        let _ = Container<Int>.Small<8>()
        print("V28e (nested Storage.Inline + HeapWrap?, nil): OK")
    }
    // V29-V30: @frozen variants
    do {
        let _ = V29a<Int, 8>()
        print("V29a (@frozen Storage.Inline + HeapBuf?): OK")
    }
    do {
        let _ = V29b<Int, 8>()
        print("V29b (@frozen Storage.Inline + HeapWrap?): OK")
    }
    do {
        let _ = V29c<Int, 8>()
        print("V29c (@frozen Storage.Inline + HeapWrap? active): OK")
    }
    do {
        var v30 = V30<Int, 8>()
        print("V30 (@frozen + @inlinable, spilled=\(v30.isSpilled)): OK")
        v30.spill()
        print("V30 (after spill, spilled=\(v30.isSpilled)): OK")
    }
}

testV13()
