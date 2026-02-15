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
// MARK: - V14: THE CRITICAL COMBINATION — @_rawLayout field + class reference
// Hypothesis: THIS is the trigger — ~Copyable struct with both @_rawLayout
//             stored property AND class reference stored property causes the
//             compiler-generated destructor to emit invalid LLVM IR.
// ============================================================================

struct V14_Combined_NoDeinit: ~Copyable {
    var inline: InlineStorage<Int>
    var heap: HeapStorage<Int>?

    init() {
        self.inline = InlineStorage()
        self.heap = nil
    }
}

struct V15_Combined_EmptyDeinit: ~Copyable {
    var inline: InlineStorage<Int>
    var heap: HeapStorage<Int>?

    init() {
        self.inline = InlineStorage()
        self.heap = nil
    }

    deinit {}
}

struct V16_Combined_Deinit: ~Copyable {
    var inline: InlineStorage<Int>
    var heap: HeapStorage<Int>?

    init() {
        self.inline = InlineStorage()
        self.heap = HeapStorage(capacity: 4)
    }

    deinit {
        // Note: cannot modify self in deinit.
        // Production crash is from IMPLICIT destructor — no explicit deinit.
        inline.cleanup()
    }
}

// ============================================================================
// MARK: - V17: Generic combined (closest to production Small pattern)
// ============================================================================

struct V17_GenericCombined<Element: ~Copyable>: ~Copyable {
    var inline: InlineStorage<Element>
    var heap: HeapStorage<Element>?

    init(inline: consuming InlineStorage<Element>) {
        self.inline = inline
        self.heap = nil
    }
}

struct V18_GenericCombinedDeinit<Element: ~Copyable>: ~Copyable {
    var inline: InlineStorage<Element>
    var heap: HeapStorage<Element>?

    init(inline: consuming InlineStorage<Element>) {
        self.inline = inline
        self.heap = nil
    }

    deinit {
        inline.cleanup()
    }
}

// ============================================================================
// MARK: - V19: Nested in generic enum (exact production pattern)
// ============================================================================

extension Namespace {
    struct Small: ~Copyable {
        var inline: InlineStorage<Element>
        var heap: HeapStorage<Element>?

        init(inline: consuming InlineStorage<Element>) {
            self.inline = inline
            self.heap = nil
        }
    }

    struct SmallWithDeinit: ~Copyable {
        var inline: InlineStorage<Element>
        var heap: HeapStorage<Element>?

        init(inline: consuming InlineStorage<Element>) {
            self.inline = inline
            self.heap = nil
        }

        deinit {
            inline.cleanup()
        }
    }
}

extension Namespace.Small: @unchecked Sendable where Element: Sendable {}
extension Namespace.SmallWithDeinit: @unchecked Sendable where Element: Sendable {}

// ============================================================================
// MARK: - V20: Value generic + combined (most production-like)
// ============================================================================

struct V20_ValueGenericCombined<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var inline: InlineStorage<Element>
    var heap: HeapStorage<Element>?

    init(inline: consuming InlineStorage<Element>) {
        self.inline = inline
        self.heap = nil
    }
}

struct V21_ValueGenericCombinedDeinit<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var inline: InlineStorage<Element>
    var heap: HeapStorage<Element>?

    init(inline: consuming InlineStorage<Element>) {
        self.inline = inline
        self.heap = nil
    }

    deinit {
        inline.cleanup()
    }
}

// ============================================================================
// MARK: - V22-V25: ManagedBuffer variants (production uses ManagedBuffer, not regular class)
// Hypothesis: ManagedBuffer's vtable-based destruction path differs from
//             regular class ARC. The LLVM verifier crash may be specific to
//             ManagedBuffer destruction sequences.
// ============================================================================

struct V22_ManagedBufCombined: ~Copyable {
    var inline: InlineStorage<Int>
    var heap: ManagedHeapStorage?

    init() {
        self.inline = InlineStorage()
        self.heap = nil
    }
}

struct V23_ManagedBufCombinedActive: ~Copyable {
    var inline: InlineStorage<Int>
    var heap: ManagedHeapStorage?

    init() {
        self.inline = InlineStorage()
        self.heap = ManagedHeapStorage.make(capacity: 8)
    }
}

// V24: HeapWrapper (struct wrapping ManagedBuffer) — matches production
// where Buffer<Element>.Ring is a struct containing a ManagedBuffer subclass
struct V24_WrappedManagedBuf: ~Copyable {
    var inline: InlineStorage<Int>
    var heap: HeapWrapper<Int>?

    init() {
        self.inline = InlineStorage()
        self.heap = nil
    }
}

struct V25_WrappedManagedBufActive: ~Copyable {
    var inline: InlineStorage<Int>
    var heap: HeapWrapper<Int>?

    init() {
        self.inline = InlineStorage()
        self.heap = HeapWrapper(capacity: 8)
    }
}

// V26: Generic wrapped ManagedBuffer (closest to production)
struct V26_GenericWrapped<Element: ~Copyable>: ~Copyable {
    var inline: InlineStorage<Element>
    var heap: HeapWrapper<Element>?

    init(inline: consuming InlineStorage<Element>) {
        self.inline = inline
        self.heap = nil
    }
}

struct V27_GenericWrappedActive<Element: ~Copyable>: ~Copyable {
    var inline: InlineStorage<Element>
    var heap: HeapWrapper<Element>?

    init(inline: consuming InlineStorage<Element>, heap: consuming HeapWrapper<Element>) {
        self.inline = inline
        self.heap = consume heap
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
    // V14-V21: Critical combination variants
    do {
        let _ = V14_Combined_NoDeinit()
        print("V14 (@_rawLayout + class, no deinit): OK")
    }
    do {
        let _ = V15_Combined_EmptyDeinit()
        print("V15 (@_rawLayout + class, empty deinit): OK")
    }
    do {
        let _ = V16_Combined_Deinit()
        print("V16 (@_rawLayout + class, deinit): OK")
    }
    do {
        let _ = V17_GenericCombined<Int>(inline: InlineStorage())
        print("V17 (generic @_rawLayout + class, no deinit): OK")
    }
    do {
        let _ = V18_GenericCombinedDeinit<Int>(inline: InlineStorage())
        print("V18 (generic @_rawLayout + class, deinit): OK")
    }
    do {
        let _ = Namespace<Int>.Small(inline: InlineStorage())
        print("V19a (nested @_rawLayout + class, no deinit): OK")
    }
    do {
        let _ = Namespace<Int>.SmallWithDeinit(inline: InlineStorage())
        print("V19b (nested @_rawLayout + class, deinit): OK")
    }
    do {
        let _ = V20_ValueGenericCombined<Int, 8>(inline: InlineStorage())
        print("V20 (value generic @_rawLayout + class, no deinit): OK")
    }
    do {
        let _ = V21_ValueGenericCombinedDeinit<Int, 8>(inline: InlineStorage())
        print("V21 (value generic @_rawLayout + class, deinit): OK")
    }
    // V22-V27: ManagedBuffer variants
    do {
        let _ = V22_ManagedBufCombined()
        print("V22 (@_rawLayout + ManagedBuffer?, nil): OK")
    }
    do {
        let _ = V23_ManagedBufCombinedActive()
        print("V23 (@_rawLayout + ManagedBuffer?, active): OK")
    }
    do {
        let _ = V24_WrappedManagedBuf()
        print("V24 (@_rawLayout + HeapWrapper?, nil): OK")
    }
    do {
        let _ = V25_WrappedManagedBufActive()
        print("V25 (@_rawLayout + HeapWrapper?, active): OK")
    }
    do {
        let _ = V26_GenericWrapped<Int>(inline: InlineStorage())
        print("V26 (generic @_rawLayout + HeapWrapper?, nil): OK")
    }
    do {
        let _ = V27_GenericWrappedActive<Int>(inline: InlineStorage(), heap: HeapWrapper(capacity: 4))
        print("V27 (generic @_rawLayout + HeapWrapper?, active): OK")
    }
}

instantiate()
