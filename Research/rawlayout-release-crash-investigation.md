# @_rawLayout Release Crash Investigation

<!--
---
version: 2.0.0
date: 2026-03-21
status: VIABLE PATH (combined @_rawLayout approach verified)
consolidates:
  - release-crash-fix-handoff.md
  - release-crash-resolution-handoff.md
  - release-build-fresh-eyes-handoff.md
  - release-build-resolution-handoff-v2.md
  - per-variant-core-split-instructions.md
  - rawlayout-experiment-consolidation-handoff.md
  - storage-inline-deinit-handoff.md
  - storage-inline-deinit-investigation-results.md
  - github-issue-86652-comment-draft.md
---
-->

## Summary

Two compiler bugs block `swift build -c release` for types combining `~Copyable` structs, `@_rawLayout` stored fields, and explicit `deinit`. The root cause is triviality misclassification: the compiler incorrectly classifies `@_rawLayout` types with generic-dependent layout as trivially destructible when imported cross-module.

**Authoritative diagnosis**: [release-mode-llvm-verifier-crash-diagnosis.md](release-mode-llvm-verifier-crash-diagnosis.md) (v3.0.0, Steps 1-8)
**Ranked workaround options**: [release-build-options-v2.md](release-build-options-v2.md)
**Experiment corpus**: [rawlayout-llvm-verifier-crash/](../Experiments/rawlayout-llvm-verifier-crash/), [rawlayout-sil-ownership-crash/](../Experiments/rawlayout-sil-ownership-crash/), [rawlayout-deinit-alternatives/](../Experiments/rawlayout-deinit-alternatives/), [rawlayout-minimal-reproducer/](../Experiments/rawlayout-minimal-reproducer/)

## Timeline

| Date | Event | Outcome |
|------|-------|---------|
| 2026-02-15 | LLVM verifier crash discovered in buffer-primitives release build | File-split hypothesis proposed → invalidated by clean builds (Step 6) |
| 2026-02-15 | Per-variant Core module split attempted | Invalidated by [MOD-004] constraint poisoning (Step 7) and cross-module boundary (Step 8) |
| 2026-03-20 | Constraint triangle documented | All modularization approaches proven impossible. "Candidate B" (reduce to ≤2 deinits) identified as viable. |
| 2026-03-20 | Workaround branch created (`workaround/struct-body-inline-types`) | Ring.Inline + Linear.Inline deinits removed. Slab.Inline + Arena.Inline retained. 391 tests pass. |
| 2026-03-21 | 14 scattered experiments consolidated into 4 | [rawlayout-experiment-consolidation-handoff.md] — corpus organized for systematic investigation |
| 2026-03-21 | Minimal reproducer found for Bug 1 | 3-module chain, 2+ cross-module @_rawLayout fields. Consumer module crashes, defining module fine. |
| 2026-03-21 | Storage.Inline deinit investigated → **provably impossible** | 2-field rule discovered. 9 approaches tested, all fail. |
| 2026-03-21 | Tested on Swift 6.4-dev (main snapshot 2026-03-16) | **Still broken.** |

## The Two Bugs

**Bug 1 — LLVM Verifier Crash** ("Instruction does not dominate all uses!"):
- Trigger: `~Copyable` struct with `@_rawLayout` stored field(s) + explicit `deinit` + `-O`
- Root cause: `invariant.load` annotation on `let` stored property accesses mis-positioned relative to `@_rawLayout` destruction sequences in LLVM IR
- Tracked: swiftlang/swift#86652

**Bug 2 — SIL Ownership Crash** ("Found ownership error?!"):
- Trigger: CopyPropagation false positive on functions using buffer types with `@_rawLayout` in dependency graph
- Context-sensitive: requires 5+ layers of `@inlinable` typed infrastructure; does not reproduce standalone
- Suppressed: `@_optimize(none)` on 4 affected functions

## The 2-Field Rule (Refined Trigger)

Discovered 2026-03-21 during Storage.Inline deinit investigation:

| Condition | Crash? |
|-----------|:------:|
| 1 @_rawLayout field + explicit deinit (even empty) + 0 deps | No |
| 1 @_rawLayout field + non-empty deinit + 0 deps | No |
| 2+ fields (1 @_rawLayout + others) + `deinit {}` (empty) + 0 deps | **YES** |
| 2+ fields (1 @_rawLayout + 1 Int) + `deinit { _ = capacity }` + 0 deps | **YES** |
| 1 field wrapping _Fields(2 fields) + `deinit {}` + 0 deps | **YES** (transitive) |
| 1 field (Storage.Inline from pre-compiled module) + `deinit {}` + 1 dep | **YES** |

The crash requires the **combination** of: (1) a `@_rawLayout` stored field at any depth in the destruction chain, (2) at least one OTHER stored field at the same nesting level, (3) an explicit `deinit` anywhere in the chain, (4) `-O` optimization.

## Why Storage.Inline Cannot Have a Deinit

Storage.Inline has 2 stored properties: `_storage: _Raw` (@_rawLayout) + `_slots: Bit.Vector.Static<4>`. This violates the 2-field rule.

**9 approaches tested, all fail:**
1. Direct deinit (enum-body pattern) → CRASH
2. `@_optimize(none)` on deinit → CRASH
3. Empty deinit body → CRASH (with 2 fields)
4. Separate module within storage-primitives → CRASH
5. Pre-compiled @_rawLayout cross-module → CRASH
6. `_Fields` wrapper (single stored property) → CRASH (transitive)
7. Top-level standalone type → CRASH
8. Shared deinit wrapper in Buffer Primitives Core → CRASH (multiplies transitive chain)
9. Wrapper in variant struct body → CRASH (same issue)

## Viable Path: Combined @_rawLayout (Discovered 2026-03-21)

The 2-field rule only triggers when there are 2+ STORED FIELDS. If the bitmap is encoded WITHIN the single `@_rawLayout` field (alongside elements), Storage.Inline has 1 stored field and CAN have a deinit.

**Approach**: Use `@_rawLayout(like: _CombinedLayout<Element, capacity>)` where `_CombinedLayout` is a struct containing both element storage and bitmap:

```swift
@_rawLayout(likeArrayOf: Element, count: capacity)
struct _RawElements<Element: ~Copyable, let capacity: Int>: ~Copyable { init() {} }

struct _CombinedLayout<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var elements: _RawElements<Element, capacity>
    var bitmap: InlineArray<4, UInt>  // 32 bytes = 256 bits
}

@_rawLayout(like: _CombinedLayout<Element, capacity>)
struct _Raw: ~Copyable { init() {} }
```

**Verified empirically** (2026-03-21):
- `@_rawLayout(like: CombinedLayout)` computes correct layout (elements + 32 bitmap bytes)
- 1-field struct with deinit builds in release without crash
- Deinit correctly accesses bitmap region via pointer arithmetic into the raw layout
- `swift run -c release` produces correct output: `CombinedRaw<Int, 4>` size = 64 (4×8 + 32)

**Consistent with stdlib**: `Atomic<Value>` uses `@_rawLayout(like: Value.AtomicRepresentation)` — the `like: T` pattern with generic T is production-proven.

**What changes**:
- `_slots` moves from a stored field to a computed property backed by pointer access into the raw region
- The bitmap lives at byte offset `stride(Element) × capacity` within the raw layout
- Storage.Inline becomes 1 field (`_raw: _Raw`) instead of 2 (`_storage + _slots`)
- Storage.Inline gains a deinit that iterates the embedded bitmap
- Buffer-layer deinits on Ring.Inline, Linear.Inline, Slab.Inline become unnecessary

**Layering note**: The bitmap remains semantically a storage concern — it's still inside Storage.Inline, just encoded within the raw layout region instead of as a separate stored field. No layering violation.

## Ideal Architecture

```
┌─────────────────────────┬──────────────────────────────────────────┐
│ Layer                   │ Cleanup responsibility                   │
├─────────────────────────┼──────────────────────────────────────────┤
│ Storage.Inline          │ Iterate _slots.ones, deinitialize        │
│ Buffer.*.Inline         │ None — delegate to Storage.Inline        │
│ Buffer.Arena.Inline     │ Own deinit — uses _Elements, not Inline  │
└─────────────────────────┴──────────────────────────────────────────┘
```

All buffer types use tracked methods (`storage.initialize`, `storage.move`, `storage.deinitialize`) which keep `_slots` in sync. Exception: Slab.Inline's deinit uses direct pointer deinitialize (would be removed in ideal architecture).

**Proposed deinit body** (for when the compiler bug is fixed):
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

## Current Workaround

Branch: `workaround/struct-body-inline-types`

1. Inline types moved from extension files into parent struct bodies (avoids extension-file trigger)
2. Ring.Inline and Linear.Inline deinits **removed** (elements leak for class-typed and ~Copyable)
3. Slab.Inline and Arena.Inline deinits **retained** (≤2 threshold satisfied)
4. `@_optimize(none)` on 4 functions for Bug 2
5. 391 tests pass, `swift build -c release` succeeds

**Known regression**: Ring.Inline and Linear.Inline silently leak elements when dropped without draining. Affects class-typed and ~Copyable elements only.

## Why the Current Workaround Works

1. Only 2 types have deinits with @_rawLayout in their destruction chain: Slab.Inline + Arena.Inline
2. Both in **variant struct bodies** (struct-body pattern)
3. Neither stores another type-with-deinit (they store Storage.Inline which has NO deinit)
4. Buffer.Aligned has a deinit but no @_rawLayout — doesn't count
5. Ring.Inline and Linear.Inline have no deinit — they leak, but the build succeeds

## Constraint Triangle

Three mutually exclusive constraints block all modularization approaches:

1. **Struct-body threshold**: ≤2 @_rawLayout+deinit types in struct-body pattern per module
2. **Extension-file pattern**: Even 1 type crashes when defined via extension
3. **Cross-module boundary**: Even 1 type crashes when extending a parent from a different module

Combined with [MOD-004] constraint poisoning (Copyable-requiring conformances in the same module as ~Copyable type definitions break stored properties), type definitions CANNOT move to variant modules.

## GitHub Issue #86652 — Consumer-Module Reproducer

### Minimal Reproduction (3 modules, zero external dependencies)

**Package.swift:**
```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "rawlayout-consumer-crash",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "Core", swiftSettings: [.enableExperimentalFeature("RawLayout")]),
        .target(name: "Middleware", dependencies: ["Core"],
                swiftSettings: [.enableExperimentalFeature("RawLayout")]),
        .executableTarget(name: "Consumer", dependencies: ["Core", "Middleware"],
                          swiftSettings: [.enableExperimentalFeature("RawLayout")]),
    ],
    swiftLanguageModes: [.v6]
)
```

**Sources/Core/Types.swift:**
```swift
public enum Container<Element: ~Copyable> {
    @_rawLayout(likeArrayOf: Element, count: capacity)
    public struct Inline<let capacity: Int>: ~Copyable {
        public init() {}
        deinit {}
    }
}
```

**Sources/Middleware/Wrappers.swift** (crash site):
```swift
public import Core

public struct Buffer<Element: ~Copyable>: ~Copyable {
    var _a: Container<Element>.Inline<8>
    var _b: Container<Element>.Inline<4>   // ← Remove this field → crash disappears

    public init() {
        self._a = .init()
        self._b = .init()
    }
}
```

**Sources/Consumer/main.swift:**
```swift
import Middleware
do { let _ = Buffer<Int>() }
print("OK")
```

```bash
rm -rf .build && swift build -c release
# signal 6: "Instruction does not dominate all uses!"
```

### Consumer-module threshold

| Fields in Middleware struct | Debug | Release |
|---------------------------|-------|---------|
| 1 field (`_a` only) | Builds | Builds |
| 2 fields (`_a` + `_b`) | Builds | **Crash** |

No `@inlinable` or `@usableFromInline` required on either side. The crash is in the consumer module's implicit destructor.

## Monitoring

When new Swift toolchains are released:

```bash
# Test consumer-module trigger:
cd Experiments/rawlayout-minimal-reproducer/
rm -rf .build && swift build -c release --target Bug1Consumer
# If this builds → the consumer-module trigger is fixed

# Test Storage.Inline deinit (add deinit {} to Storage.Inline):
cd /Users/coen/Developer/swift-primitives/swift-storage-primitives
rm -rf .build && swift build -c release
# If this builds → the 2-field trigger is fixed
```

## Cross-References

- [release-mode-llvm-verifier-crash-diagnosis.md](release-mode-llvm-verifier-crash-diagnosis.md) — Authoritative diagnosis (v3.0.0)
- [release-build-options-v2.md](release-build-options-v2.md) — Ranked workaround options
- [small-buffer-enum-compiler-workarounds.md](small-buffer-enum-compiler-workarounds.md) — Related DECISION: Small enum compiler bugs
- [rawlayout-llvm-verifier-crash/](../Experiments/rawlayout-llvm-verifier-crash/) — Bug 1 experiment corpus (8 variants)
- [rawlayout-sil-ownership-crash/](../Experiments/rawlayout-sil-ownership-crash/) — Bug 2 experiment corpus (3 variants)
- [rawlayout-deinit-alternatives/](../Experiments/rawlayout-deinit-alternatives/) — Workaround alternatives (4 variants)
- [rawlayout-minimal-reproducer/](../Experiments/rawlayout-minimal-reproducer/) — Standalone reproducer
