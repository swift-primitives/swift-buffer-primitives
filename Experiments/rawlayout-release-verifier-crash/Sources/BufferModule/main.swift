// MARK: - LLVM Verifier Crash: Release Build Isolation
// Purpose: Identify the exact primitive that triggers "Instruction does not
//          dominate all uses!" LLVM verifier crash in release builds.
// Hypothesis: The crash is caused by ~Copyable structs containing @_rawLayout
//             fields when the compiler generates implicit or explicit destructors.
//
// Methodology: Incremental construction per [EXP-004a]. Each variant adds one
//              factor. When the crash appears, the last-added factor is the cause.
//
// Toolchain: Xcode 26.0 beta 2 (Swift 6.2)
// Platform: macOS 26.0 (arm64)
//
// Result: (pending)
// Date: 2026-02-15

import StorageModule

// ============================================================================
// MARK: - V1: ~Copyable struct, heap-backed (class ref), no deinit
// Hypothesis: No crash — class references don't involve @_rawLayout
// ============================================================================

struct V1_HeapNoDeinit: ~Copyable {
    var header: Int
    var storage: HeapStorage<Int>

    init() {
        self.header = 0
        self.storage = HeapStorage(capacity: 8)
    }
}

// ============================================================================
// MARK: - V2: ~Copyable struct, heap-backed, WITH deinit
// Hypothesis: No crash — class references don't involve @_rawLayout
// ============================================================================

struct V2_HeapWithDeinit: ~Copyable {
    var header: Int
    var storage: HeapStorage<Int>

    init() {
        self.header = 0
        self.storage = HeapStorage(capacity: 8)
    }

    deinit {
        storage.cleanup()
    }
}

// ============================================================================
// MARK: - V3: ~Copyable struct, @_rawLayout field ONLY (no extra stored props)
// Hypothesis: No crash — single @_rawLayout field without additional fields
// ============================================================================

struct V3_RawLayoutOnly: ~Copyable {
    var storage: InlineStorage<Int>

    init() {
        self.storage = InlineStorage()
    }
}

// ============================================================================
// MARK: - V4: ~Copyable struct, @_rawLayout field + additional stored property, NO deinit
// Hypothesis: THIS might crash — the combination of @_rawLayout + stored prop
//             forces compiler to generate implicit destructor with stride math
// ============================================================================

struct V4_RawLayoutPlusField: ~Copyable {
    var header: Int
    var storage: InlineStorage<Int>

    init(header: Int) {
        self.header = header
        self.storage = InlineStorage()
    }
}

// ============================================================================
// MARK: - V5: Same as V4 but with empty deinit
// Hypothesis: Empty deinit adds explicit destruction path
// ============================================================================

struct V5_RawLayoutEmptyDeinit: ~Copyable {
    var header: Int
    var storage: InlineStorage<Int>

    init(header: Int) {
        self.header = header
        self.storage = InlineStorage()
    }

    deinit {}
}

// ============================================================================
// MARK: - V6: Same as V4 but with deinit that calls cleanup
// Hypothesis: Deinit body with stride-based logic
// ============================================================================

struct V6_RawLayoutDeinitCleanup: ~Copyable {
    var header: Int
    var storage: InlineStorage<Int>

    init(header: Int) {
        self.header = header
        self.storage = InlineStorage()
    }

    deinit {
        storage.cleanup()
    }
}

// ============================================================================
// MARK: - V7: Generic ~Copyable Element (matches production pattern)
// Hypothesis: Generic Element causes stride to be runtime-computed
// ============================================================================

struct V7_Generic<Element: ~Copyable>: ~Copyable {
    var header: Int
    var storage: InlineStorage<Element>

    init(header: Int, storage: consuming InlineStorage<Element>) {
        self.header = header
        self.storage = storage
    }
}

// ============================================================================
// MARK: - V8: Generic + deinit (closest to production)
// Hypothesis: Generic Element + deinit = most likely crash
// ============================================================================

struct V8_GenericDeinit<Element: ~Copyable>: ~Copyable {
    var header: Int
    var storage: InlineStorage<Element>

    init(header: Int, storage: consuming InlineStorage<Element>) {
        self.header = header
        self.storage = storage
    }

    deinit {
        storage.cleanup()
    }
}

// ============================================================================
// MARK: - V9: Nested inside generic enum (matches Buffer<Element> pattern)
// Hypothesis: Nesting inside generic ~Copyable enum is the trigger
// ============================================================================

enum Namespace<Element: ~Copyable> {
    struct Inline: ~Copyable {
        var header: Int
        var storage: InlineStorage<Element>

        init(header: Int, storage: consuming InlineStorage<Element>) {
            self.header = header
            self.storage = storage
        }
    }

    struct InlineWithDeinit: ~Copyable {
        var header: Int
        var storage: InlineStorage<Element>

        init(header: Int, storage: consuming InlineStorage<Element>) {
            self.header = header
            self.storage = storage
        }

        deinit {
            storage.cleanup()
        }
    }
}

// ============================================================================
// MARK: - V10: Conditional Sendable conformance (matches production)
// Hypothesis: Conditional conformance generates additional metadata paths
// Note: Copyable suppressed because @_rawLayout is unconditionally ~Copyable
// ============================================================================

// Copyable suppressed — InlineStorage uses @_rawLayout (unconditionally ~Copyable)
// extension V7_Generic: Copyable where Element: Copyable {}
extension V7_Generic: @unchecked Sendable where Element: Sendable {}

extension Namespace.Inline: @unchecked Sendable where Element: Sendable {}
extension Namespace.InlineWithDeinit: @unchecked Sendable where Element: Sendable {}

// ============================================================================
// MARK: - V11: Value generic (matches production <let capacity: Int>)
// Hypothesis: Value generics + @_rawLayout + generic Element
// ============================================================================

struct V11_ValueGeneric<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var header: Int
    var storage: InlineStorage<Element>

    init(header: Int, storage: consuming InlineStorage<Element>) {
        self.header = header
        self.storage = storage
    }
}

struct V12_ValueGenericDeinit<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var header: Int
    var storage: InlineStorage<Element>

    init(header: Int, storage: consuming InlineStorage<Element>) {
        self.header = header
        self.storage = storage
    }

    deinit {
        storage.cleanup()
    }
}

// ============================================================================
// MARK: - Instantiation (force specialization in this module)
// ============================================================================

func instantiate() {
    do {
        let _ = V1_HeapNoDeinit()
        print("V1 (heap, no deinit): OK")
    }
    do {
        let _ = V2_HeapWithDeinit()
        print("V2 (heap, with deinit): OK")
    }
    do {
        let _ = V3_RawLayoutOnly()
        print("V3 (@_rawLayout only): OK")
    }
    do {
        let _ = V4_RawLayoutPlusField(header: 42)
        print("V4 (@_rawLayout + field, no deinit): OK")
    }
    do {
        let _ = V5_RawLayoutEmptyDeinit(header: 42)
        print("V5 (@_rawLayout + field, empty deinit): OK")
    }
    do {
        let _ = V6_RawLayoutDeinitCleanup(header: 42)
        print("V6 (@_rawLayout + field, deinit cleanup): OK")
    }
    do {
        let _ = V7_Generic<Int>(header: 42, storage: InlineStorage())
        print("V7 (generic, no deinit): OK")
    }
    do {
        let _ = V8_GenericDeinit<Int>(header: 42, storage: InlineStorage())
        print("V8 (generic, deinit): OK")
    }
    do {
        let _ = Namespace<Int>.Inline(header: 42, storage: InlineStorage())
        print("V9a (nested, no deinit): OK")
    }
    do {
        let _ = Namespace<Int>.InlineWithDeinit(header: 42, storage: InlineStorage())
        print("V9b (nested, with deinit): OK")
    }
    do {
        let _ = V11_ValueGeneric<Int, 8>(header: 42, storage: InlineStorage())
        print("V11 (value generic, no deinit): OK")
    }
    do {
        let _ = V12_ValueGenericDeinit<Int, 8>(header: 42, storage: InlineStorage())
        print("V12 (value generic, deinit): OK")
    }
}

instantiate()
