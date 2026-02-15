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
}

testV13()
