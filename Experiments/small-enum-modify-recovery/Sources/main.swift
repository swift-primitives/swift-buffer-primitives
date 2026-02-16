// MARK: - Small Enum _modify Recovery
// Purpose: Test whether the DiagnoseStaticExclusivity crash (signal 11) on
//          `yield unsafe &storage.pointer(at:).pointee` through a borrowed
//          enum payload is fixed in the current toolchain.
//
// Background: noncopyable-enum-modify proved that enum _modify is a language
//             limitation (can't yield &payload directly). The buffer-primitives
//             code used an UNSAFE pointer bypass that crashed the compiler.
//             var-binding approaches fail with "missing reinitialization of
//             inout parameter 'self' after consume" (V7 in prior experiment).
//             The only remaining path is the let-binding pointer bypass.
//
// Hypothesis: The DiagnoseStaticExclusivity crash may be fixed in Swift 6.2.3.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21 clang-1700.6.3.2)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — DiagnoseStaticExclusivity crash is FIXED. Heap _modify
//         works via let-binding pointer bypass (debug + release). Inline
//         _modify via let binding does NOT persist mutations (pointer into
//         borrow temporary). withUnsafeMutablePointer works in debug but
//         breaks under release optimization. Production fix: recover heap
//         _modify, spill inline to heap on _modify (ensureHeap pattern).
// Date: 2026-02-16

// =============================================================================
// MARK: - Setup: Minimal reproduction of Buffer.Linear.Small structure
// =============================================================================

/// Simulates Storage.Heap — a CLASS (reference type) so pointer(at:) is non-mutating.
@unsafe
class HeapStorage {
    let ptr: UnsafeMutablePointer<Int>

    init(capacity: Int) {
        ptr = unsafe .allocate(capacity: capacity)
    }

    @unsafe
    func pointer(at index: Int) -> UnsafeMutablePointer<Int> {
        unsafe ptr.advanced(by: index)
    }

    deinit {
        unsafe ptr.deallocate()
    }
}

/// Simulates Storage.Inline — a struct with non-mutating pointer access.
struct InlineStorage: ~Copyable {
    var _e0: Int = 0
    var _e1: Int = 0

    @unsafe
    func pointer(at index: Int) -> UnsafeMutablePointer<Int> {
        unsafe withUnsafePointer(to: _e0) {
            unsafe UnsafeMutablePointer(mutating: $0.advanced(by: index))
        }
    }
}

/// Simulates Buffer.Linear (heap-backed).
struct HeapBuffer: ~Copyable {
    var count: Int = 0
    var storage: HeapStorage

    init() {
        storage = unsafe HeapStorage(capacity: 16)
    }
}

/// Simulates Buffer.Linear.Inline (inline-backed).
struct InlineBuffer: ~Copyable {
    var count: Int = 0
    var storage: InlineStorage = .init()
}

/// The @frozen ~Copyable enum — reproduces Buffer.Linear.Small._Representation.
@frozen
enum SmallRep: ~Copyable {
    case inline(InlineBuffer)
    case heap(HeapBuffer)
}

// =============================================================================
// MARK: - V1: _modify with let binding, yield through pointer (heap only)
// Hypothesis: Heap case yields through storage.pointer(at:).pointee where
//             storage is a class — the pointer goes into heap allocation,
//             NOT into the enum payload. This should not alias with self.
// Result: CONFIRMED — heap path: 42→99 (debug+release). No crash.
// =============================================================================

struct V1_HeapOnly: ~Copyable {
    var _storage: SmallRep

    subscript(index: Int) -> Int {
        _read {
            switch _storage {
            case .heap(let heap):
                yield unsafe heap.storage.pointer(at: index).pointee
            case .inline(let buf):
                yield unsafe buf.storage.pointer(at: index).pointee
            }
        }
        _modify {
            switch _storage {
            case .heap(let heap):
                // Pointer into HEAP allocation — does NOT alias enum payload
                yield unsafe &heap.storage.pointer(at: index).pointee
            case .inline(_):
                fatalError("_modify not supported for inline case")
            }
        }
    }
}

// =============================================================================
// MARK: - V2: _modify with let binding, yield through pointer (both cases)
// Hypothesis: The original crash pattern. Both heap and inline cases yield
//             through a pointer obtained from let-bound payload.
//             For inline, the pointer IS into the enum payload.
// Result: PARTIAL — heap: 42→99. Inline: mutation lost (42→42 debug, 0→0 release).
//         Pointer from let-borrow goes into temporary, not self's memory.
// =============================================================================

struct V2_BothCases: ~Copyable {
    var _storage: SmallRep

    subscript(index: Int) -> Int {
        _read {
            switch _storage {
            case .heap(let heap):
                yield unsafe heap.storage.pointer(at: index).pointee
            case .inline(let buf):
                yield unsafe buf.storage.pointer(at: index).pointee
            }
        }
        _modify {
            switch _storage {
            case .heap(let heap):
                yield unsafe &heap.storage.pointer(at: index).pointee
            case .inline(let buf):
                yield unsafe &buf.storage.pointer(at: index).pointee
            }
        }
    }
}

// =============================================================================
// MARK: - V3: _modify with let binding, yield through delegated subscript
// Hypothesis: Instead of raw pointer bypass, delegate to the inner type's
//             own subscript which already has _modify. The issue is that
//             the let binding prevents mutation — but what if the inner
//             subscript is on a class-backed type?
// Result: CONFIRMED — heap path: 42→99 (debug+release). No crash.
// =============================================================================

struct V3_DelegateSubscript: ~Copyable {
    var _storage: SmallRep

    subscript(index: Int) -> Int {
        _read {
            switch _storage {
            case .heap(let heap):
                yield unsafe heap.storage.pointer(at: index).pointee
            case .inline(let buf):
                yield unsafe buf.storage.pointer(at: index).pointee
            }
        }
        _modify {
            // Heap case only — storage is a class, so pointer access is non-mutating
            switch _storage {
            case .heap(let heap):
                let ptr = unsafe heap.storage.pointer(at: index)
                yield unsafe &ptr.pointee
            case .inline(_):
                fatalError("_modify not supported for inline")
            }
        }
    }
}

// =============================================================================
// MARK: - Execution
// =============================================================================

func testV1() {
    print("=== V1: Heap-only _modify through pointer ===")
    var heap = HeapBuffer()
    heap.count = 1
    unsafe heap.storage.pointer(at: 0).initialize(to: 42)
    var v = V1_HeapOnly(_storage: .heap(heap))
    print("Before: \(v[0])")
    v[0] = 99
    print("After:  \(v[0])")
}

func testV2Heap() {
    print("\n=== V2: Both cases _modify — heap path ===")
    var heap = HeapBuffer()
    heap.count = 1
    unsafe heap.storage.pointer(at: 0).initialize(to: 42)
    var v = V2_BothCases(_storage: .heap(heap))
    print("Before: \(v[0])")
    v[0] = 99
    print("After:  \(v[0])")
}

func testV2Inline() {
    print("\n=== V2: Both cases _modify — inline path ===")
    var buf = InlineBuffer()
    buf.storage._e0 = 42  // direct initialization
    var v = V2_BothCases(_storage: .inline(buf))
    print("Before: \(v[0])")
    v[0] = 99
    print("After:  \(v[0])")
}

func testV3() {
    print("\n=== V3: Delegate subscript — heap only ===")
    var heap = HeapBuffer()
    heap.count = 1
    unsafe heap.storage.pointer(at: 0).initialize(to: 42)
    var v = V3_DelegateSubscript(_storage: .heap(heap))
    print("Before: \(v[0])")
    v[0] = 99
    print("After:  \(v[0])")
}

// =============================================================================
// MARK: - V4: Separated pointer computation — borrow ends before yield
// Hypothesis: Compute the pointer inside the switch (borrow), then yield
//             AFTER the switch ends (borrow released). The pointer is a raw
//             UnsafeMutablePointer — it doesn't participate in ownership.
//             self is inout during _modify, so the memory is exclusively held.
// Result: PARTIAL — same as V2. Separating pointer computation from yield
//         does not help; the pointer is still computed from a let-borrow temporary.
// =============================================================================

struct V4_SeparatedPointer: ~Copyable {
    var _storage: SmallRep

    subscript(index: Int) -> Int {
        _read {
            switch _storage {
            case .heap(let heap):
                yield unsafe heap.storage.pointer(at: index).pointee
            case .inline(let buf):
                yield unsafe buf.storage.pointer(at: index).pointee
            }
        }
        _modify {
            let ptr: UnsafeMutablePointer<Int>
            switch _storage {
            case .heap(let heap):
                ptr = unsafe heap.storage.pointer(at: index)
            case .inline(let buf):
                ptr = unsafe buf.storage.pointer(at: index)
            }
            // Borrow of _storage ended. ptr is a raw pointer into self's memory.
            // self is inout during _modify — memory is exclusively held.
            yield unsafe &ptr.pointee
        }
    }
}

func testV4Heap() {
    print("\n=== V4: Separated pointer — heap path ===")
    var heap = HeapBuffer()
    heap.count = 1
    unsafe heap.storage.pointer(at: 0).initialize(to: 42)
    var v = V4_SeparatedPointer(_storage: .heap(heap))
    print("Before: \(v[0])")
    v[0] = 99
    print("After:  \(v[0])")
}

func testV4Inline() {
    print("\n=== V4: Separated pointer — inline path ===")
    var buf = InlineBuffer()
    buf.storage._e0 = 42
    var v = V4_SeparatedPointer(_storage: .inline(buf))
    print("Before: \(v[0])")
    v[0] = 99
    print("After:  \(v[0])")
}

// =============================================================================
// MARK: - V5: withUnsafeMutablePointer for inline, let for heap
// Hypothesis: withUnsafeMutablePointer(to: &_storage) gives a MUTABLE pointer
//             into self's actual memory. For inline case, project into the
//             enum payload at the correct offset. For heap, use let binding.
// Result: PARTIAL — inline: 42→99 in DEBUG, 0→0 in RELEASE. Optimizer breaks
//         the raw pointer projection. Heap: works in both modes.
//         withUnsafeMutablePointer gives correct address in debug but the
//         optimizer doesn't preserve the store-through-raw-pointer chain.
// =============================================================================

struct V5_MutableSelfPointer: ~Copyable {
    var _storage: SmallRep

    subscript(index: Int) -> Int {
        _read {
            switch _storage {
            case .heap(let heap):
                yield unsafe heap.storage.pointer(at: index).pointee
            case .inline(let buf):
                yield unsafe buf.storage.pointer(at: index).pointee
            }
        }
        _modify {
            // Take exclusive access to _storage, then dispatch inside closure
            let ptr: UnsafeMutablePointer<Int> = unsafe withUnsafeMutablePointer(to: &_storage) { storagePtr in
                switch storagePtr.pointee {
                case .heap(let heap):
                    // Heap: pointer into separate allocation via class reference
                    return unsafe heap.storage.pointer(at: index)
                case .inline:
                    // Inline: project directly into the enum's memory
                    // Layout: [InlineBuffer.count: Int] [InlineStorage._e0: Int] ...
                    return unsafe UnsafeMutableRawPointer(storagePtr)
                        .advanced(by: MemoryLayout<Int>.stride) // skip count
                        .assumingMemoryBound(to: Int.self)
                        .advanced(by: index)
                }
            }
            yield unsafe &ptr.pointee
        }
    }
}

func testV5Heap() {
    print("\n=== V5: Mutable self pointer — heap path ===")
    var heap = HeapBuffer()
    heap.count = 1
    unsafe heap.storage.pointer(at: 0).initialize(to: 42)
    var v = V5_MutableSelfPointer(_storage: .heap(heap))
    print("Before: \(v[0])")
    v[0] = 99
    print("After:  \(v[0])")
}

func testV5Inline() {
    print("\n=== V5: Mutable self pointer — inline path ===")
    var buf = InlineBuffer()
    buf.storage._e0 = 42
    var v = V5_MutableSelfPointer(_storage: .inline(buf))
    print("Before: \(v[0])")
    v[0] = 99
    print("After:  \(v[0])")
}

testV1()
testV2Heap()
testV2Inline()
testV3()
testV4Heap()
testV4Inline()
testV5Heap()
testV5Inline()

// =============================================================================
// MARK: - Results Summary
//
// V1: CONFIRMED — Heap-only _modify through let-binding pointer bypass. No crash.
// V2: PARTIAL   — Heap works. Inline mutation lost (let-borrow temporary).
// V3: CONFIRMED — Heap-only _modify via delegated pointer. Same as V1.
// V4: PARTIAL   — Separated pointer computation. Same failure as V2 for inline.
// V5: PARTIAL   — withUnsafeMutablePointer works in debug, breaks in release.
//
// KEY FINDING: The DiagnoseStaticExclusivity crash is FIXED in Swift 6.2.3.
//              All variants compile without signal 11 in both debug and release.
//
// HEAP _modify: FULLY RECOVERED. The pointer goes through a class reference
//   into a separate heap allocation. Does not alias the enum payload.
//   Works in both debug and release.
//
// INLINE _modify: NOT RECOVERABLE via pointer bypass. The pointer goes into
//   the enum payload's memory, which is only accessible through a borrow
//   temporary in switch context. Three failed approaches:
//   - let binding: pointer into borrow temporary (mutation lost)
//   - var binding: "missing reinitialization of self after consume"
//   - withUnsafeMutablePointer: optimizer breaks the raw pointer chain
//
// PRODUCTION RECOMMENDATION:
//   Recover _modify on Buffer.Linear.Small with split strategy:
//   - Heap case: `let heap` binding + pointer bypass (zero-cost, proven)
//   - Inline case: spill to heap first, then yield through heap pointer
//     (mirrors Copyable variant's ensureUnique() → ensureHeap() pattern)
//
// See also: noncopyable-enum-modify (language-level proof)
// =============================================================================
