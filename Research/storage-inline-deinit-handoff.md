# Handoff: Storage.Inline Deinit — Ideal Layering Investigation

## Your Mission

Determine whether `Storage<Element>.Inline<capacity>` can have its own `deinit` in swift-storage-primitives, eliminating the need for buffer-layer deinits on Ring.Inline, Linear.Inline, Slab.Inline, and Linked.Inline. Arena.Inline is excluded — it uses its own `_Elements` (@_rawLayout), not Storage.Inline.

If this is achievable, implement it. If provably impossible with the current compiler, document exactly why with empirical evidence.

## The Ideal Architecture

```
┌──────────────────────────────────────────────┬──────────────────────────────────────────────────┐
│ Layer                                        │ Cleanup responsibility                           │
├──────────────────────────────────────────────┼──────────────────────────────────────────────────┤
│ Storage.Inline                               │ Iterate _slots.ones, deinitialize elements       │
│ Storage.Heap                                 │ Iterate initialization ranges, deinitialize       │
│ Buffer.*.Inline (Ring, Linear, Slab, Linked) │ None — delegate to Storage.Inline                │
│ Buffer.Arena.Inline                          │ Own deinit — uses _Elements, not Storage.Inline  │
│ Buffer.* (heap variants)                     │ None — delegate to Storage.Heap                  │
└──────────────────────────────────────────────┴──────────────────────────────────────────────────┘
```

This mirrors how heap variants work: `Storage.Heap` owns the cleanup, buffer types delegate. The current buffer-layer deinits on Ring.Inline, Linear.Inline, and Slab.Inline exist only because Storage.Inline lacks a deinit. They are redundant — they duplicate exactly what Storage.Inline's deinit would do.

## Why This Matters

Without a deinit on Storage.Inline, Ring.Inline and Linear.Inline (whose deinits were removed to work around Bug 1) silently leak class-typed and ~Copyable elements when dropped without draining. This is a correctness regression.

## The Compiler Bug

Two bugs in Swift 6.2.4 (also present in 6.4-dev 2026-03-16):

**Bug 1 — LLVM Verifier Crash** ("Instruction does not dominate all uses!"):
- Trigger: `~Copyable` struct whose destruction chain involves `@_rawLayout` types + explicit `deinit` + `-O`
- Extension-file pattern: threshold 0 (even 1 type crashes)
- Struct-body pattern: threshold ≤2 per WMO translation unit
- Filed: https://github.com/swiftlang/swift/issues/86652

**Bug 2 — SIL Ownership Crash** ("Found ownership error?!"):
- CopyPropagation false positive on functions using buffer types with @_rawLayout in dependency graph
- Suppressed with `@_optimize(none)` on affected functions (4 total)

## Current State (branch `workaround/struct-body-inline-types`)

Buffer-primitives builds in release without `.unsafeFlags`. The solution:
1. Moved Inline types from extension files into parent struct bodies (avoids extension-file trigger)
2. Removed Ring.Inline and Linear.Inline deinits (reduces to ≤2 deinit types: Slab + Arena)
3. `@_optimize(none)` on 4 functions for Bug 2
4. 391 tests pass, `swift build -c release` succeeds

## What Was Tried For Storage.Inline Deinit

**Attempt**: Move Storage.Inline into Storage's enum body (struct-body pattern) in storage-primitives, add a deinit.

**Result**: LLVM verifier crash. Even 1 @_rawLayout+deinit type in struct-body crashes in storage-primitives. The cross-module SIL from storage-primitives' 4 dependencies (Index Primitives, Memory Primitives, Bit Vector Primitives, Finite Primitives) is sufficient to trigger the bug at threshold 0.

**Build command used**:
```bash
cd /Users/coen/Developer/swift-primitives/swift-storage-primitives
rm -rf .build && swift build -c release
```

**Error**: 2× "Instruction does not dominate all uses!" in Storage_Primitives_Core

**This was a single attempt.** There may be angles that weren't explored. See "What You Should Investigate" below.

## Key Finding: All Buffer Types Use Tracked Methods

Confirmed empirically — no buffer type bypasses Storage.Inline's `_slots` tracking:

| Operation | Method used | Sets/clears _slots? |
|-----------|------------|-------------------|
| Initialize element | `storage.initialize(to:at:)` | Yes — sets bit |
| Move element out | `storage.move(at:)` | Yes — clears bit |
| Deinitialize element | `storage.deinitialize(at:)` | Yes — clears bit |
| Deinitialize range | `storage.deinitialize(range:)` | Yes — clears bits |

No code uses `storage.pointer(at:).initialize(to:)` or `.deinitialize(count:)` (which would bypass tracking). Exception: Slab.Inline's current deinit uses direct pointer deinitialize (but this deinit would be removed in the ideal architecture).

**Implication**: If Storage.Inline has a deinit, `_slots` accurately reflects which elements need cleanup. No double-deinitialization risk — as long as the buffer-layer deinits are removed.

## What You Should Investigate

### 1. Why does storage-primitives crash with threshold 0?

Buffer-primitives has threshold ≤2 in struct-body pattern. Storage-primitives crashes with even 1 type. What's different?

- Buffer Primitives Core imports: Storage Primitives, Cyclic Index Primitives, Memory Primitives, Bit Vector Primitives
- Storage Primitives Core imports: Index Primitives, Memory Primitives, Bit Vector Primitives, Finite Primitives

Is it a specific import that lowers the threshold? Try removing imports one at a time from Storage Primitives Core and test if the crash persists. (You'll need to temporarily comment out code that uses the removed import.)

### 2. Can Storage.Inline live in a separate module within storage-primitives?

Create a new target (e.g., "Storage Inline Core") that:
- Contains ONLY Storage.Inline (with deinit) in a top-level struct or enum body
- Has minimal imports (only what's needed for the deinit body)
- Is depended upon by "Storage Primitives Core"

Fewer imports = less cross-module SIL = possibly higher threshold. The deinit body needs:
- `_slots.ones` iteration (from Bit Vector Primitives)
- Pointer arithmetic to element slots (from stdlib + Index Primitives)

### 3. Can the deinit body avoid the trigger?

The deinit needs to iterate set bits and deinitialize elements. What if the deinit body is empty (`deinit {}`) — does the crash still occur? If yes, the trigger is the PRESENCE of deinit, not its body. If no, the body content matters.

Test sequence:
```swift
// Test A: empty deinit
deinit {}

// Test B: trivial body (no @_rawLayout access)
deinit { _ = _slots }

// Test C: full cleanup body
deinit { for bitIndex in _slots.ones { /* deinitialize */ } }
```

### 4. Can Storage.Inline be a top-level type (not nested)?

The extension-file and struct-body patterns affect nested types. What about a top-level struct?

```swift
// NOT nested in Storage — standalone type
public struct _StorageInline<Element: ~Copyable, let capacity: Int>: ~Copyable {
    // ... same fields ...
    deinit { /* cleanup */ }
}

// Typealias preserves API
extension Storage where Element: ~Copyable {
    public typealias Inline<let capacity: Int> = _StorageInline<Element, capacity>
}
```

Questions: Does Swift support value-generic typealiases? Does a top-level type avoid the crash? Does the typealias in the extension trigger the extension-file pattern?

### 5. Can we use a separate package for just this type?

Create a new package (e.g., `swift-storage-inline-core`) that:
- Contains ONLY the Storage.Inline type with deinit
- Has zero or minimal dependencies
- Is consumed by storage-primitives as a local path dependency

Fewer dependencies = less cross-module SIL = threshold might be >0.

**Critical**: Does SPM propagate the `.unsafeFlags` restriction through local path dependencies of remote packages? If not, this package could use `.unsafeFlags` as a last resort while still allowing the parent chain to be consumed as remote dependencies.

### 6. Can `@_optimize(none)` on the deinit work in storage-primitives?

In buffer-primitives, `@_optimize(none)` on deinits didn't help because the crash was in type metadata code in OTHER files, not in the destructor function. But storage-primitives has different compilation characteristics. Test:

```swift
@_optimize(none)
deinit {
    for bitIndex in _slots.ones { /* cleanup */ }
}
```

### 7. Does the nightly compiler fix the bug?

The handoff document says "Still broken on Swift 6.4-dev (main snapshot 2026-03-16)." Check if a more recent nightly has fixed it. Download from https://www.swift.org/install/ and test:

```bash
# With nightly toolchain:
cd /Users/coen/Developer/swift-primitives/swift-storage-primitives
rm -rf .build && swift build -c release
```

## Files You Need To Read

In storage-primitives (`/Users/coen/Developer/swift-primitives/swift-storage-primitives/`):
1. `Sources/Storage Primitives Core/Storage.swift` — Storage enum + Initialization
2. `Sources/Storage Primitives Core/Storage.Inline.swift` — current Inline definition (NO deinit, extension-file pattern)
3. `Sources/Storage Inline Primitives/Storage.Inline+Deinitialize.swift` — the non-mutating deinitialize that Ring/Linear deinits used to call
4. `Sources/Storage Inline Primitives/Storage.Inline ~Copyable.swift` — pointer methods
5. `Package.swift` — target structure and dependencies
6. `Sources/Storage Primitives Core/exports.swift` — re-exported modules

In buffer-primitives (`/Users/coen/Developer/swift-primitives/swift-buffer-primitives/`):
7. `Sources/Buffer Primitives Core/Buffer.Ring.swift` — Ring.Inline in struct body, deinit commented out
8. `Sources/Buffer Primitives Core/Buffer.Slab.swift` — Slab.Inline in struct body, deinit retained
9. `Sources/Buffer Primitives Core/Buffer.Arena.swift` — Arena.Inline in struct body, deinit retained (uses _Elements, not Storage.Inline)
10. `Research/release-mode-llvm-verifier-crash-diagnosis.md` — full diagnosis
11. `Research/release-build-options-v2.md` — ranked options
12. `Experiments/rawlayout-minimal-reproducer/` — standalone Bug 1 reproducer

## The Deinit Body (for reference)

If Storage.Inline can have a deinit, the body should be:

```swift
deinit {
    for bitIndex in _slots.ones {
        let slot = bitIndex.retag(Element.self)
        unsafe withUnsafePointer(to: _storage) { base in
            let elementBase = unsafe UnsafeMutableRawPointer(mutating: UnsafeRawPointer(base))
                .assumingMemoryBound(to: Element.self)
            unsafe (elementBase + Index<Element>.Offset(fromZero: slot))
                .deinitialize(count: 1)
        }
    }
}
```

This matches the existing non-mutating `callAsFunction()` in Storage.Inline+Deinitialize.swift, but implemented directly (since the Property.View accessor isn't available in Storage Primitives Core).

## Success Criteria

1. `Storage.Inline` has a deinit that cleans up initialized elements
2. `swift build -c release` succeeds for BOTH storage-primitives AND buffer-primitives, without `.unsafeFlags`
3. Ring.Inline, Linear.Inline, Slab.Inline, and Linked.Inline have NO deinit (cleanup delegated to Storage.Inline)
4. Arena.Inline retains its deinit (uses _Elements, not Storage.Inline)
5. All existing tests pass

## If Provably Impossible

Document:
1. Which specific configurations were tested (with build commands and error output)
2. Why the compiler bug makes it impossible (not just "it crashed" — show which threshold applies and why it can't be satisfied)
3. Whether any configuration gets CLOSE (e.g., threshold 1 in some module — maybe a future compiler improvement raises it to 1)
4. Recommended monitoring: what to test when new Swift toolchains are released
