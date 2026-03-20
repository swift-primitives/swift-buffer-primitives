# Release Mode LLVM Verifier Crash: Root Cause Diagnosis

<!--
---
version: 2.0.0
last_updated: 2026-03-20
status: OPEN
decision: v1.0 file-split decision invalidated — see Step 6. Needs new approach.
---
-->

## Context

`swift build -c release` and `swift test -c release` crash across the entire ecosystem because buffer-primitives (tier 15) is a transitive dependency of everything. The crash is "Instruction does not dominate all uses!" in the LLVM verifier — signal 6.

**Toolchain**: Swift 6.2.4 (Xcode, arm64 macOS 26)
**Prior research**: [small-buffer-enum-compiler-workarounds.md](small-buffer-enum-compiler-workarounds.md) — same LLVM verifier error class, different trigger

## Question

What triggers the crash, and what is the minimal fix?

## Diagnosis

### Step 1: Isolate the failing target

Storage Primitives builds fine in release. The crash is in **Buffer Primitives Core**.

### Step 2: Isolate the trigger within the target

Systematic elimination by emptying files:

| Condition | Crash? |
|-----------|:------:|
| All files empty except `exports.swift` + `Buffer.swift` | Yes (4 errors) |
| All files empty except `exports.swift` | No |
| `exports.swift` with only `@_exported public import Storage_Primitives` | No |
| `exports.swift` with only `@_exported public import Cyclic_Index_Primitives` | No |
| Both `Storage_Primitives` + `Cyclic_Index_Primitives` imported, `Buffer.swift` empty | No |
| Both imports + `Buffer.swift` with type declarations | **Yes (4 errors)** |

**Finding**: The crash requires the **combination** of `Storage_Primitives` + `Cyclic_Index_Primitives` imports together with `Buffer.swift`'s type declarations in the same compilation unit.

### Step 3: Isolate the declarations within Buffer.swift

`Buffer.swift` is a 1345-line monolithic file containing all buffer type declarations (Ring, Linear, Slab, Linked, Arena + all nested types). Four types have `deinit` blocks on `~Copyable` structs with `@_rawLayout` stored fields:

| Type | Line | deinit | Fields |
|------|------|--------|--------|
| `Buffer.Ring.Inline` | 83 | `storage.deinitialize()` | `header: Header` + `storage: Storage<Element>.Inline<capacity>` |
| `Buffer.Linear.Inline` | 319 | `storage.deinitialize()` | `header: Header` + `storage: Storage<Element>.Inline<capacity>` |
| `Buffer.Slab.Inline` | 472 | bitmap-driven iteration | `header: Header.Static<wordCount>` + `storage: Storage<Element>.Inline<wordCount>` |
| `Buffer.Arena.Inline` | ~1019 | meta-driven iteration | `header: Header` + `_meta: InlineArray` + `_elements: _Elements` (@_rawLayout) |

Disabling all 4 deinit bodies → **0 errors**. Each deinit individually contributes to the crash count.

### Step 4: Test the file split hypothesis (INVALIDATED — see Step 6)

Moving the 4 Inline types into separate `.swift` files (same module, same code, no workarounds):

| Condition | Errors |
|-----------|:------:|
| All 4 types in one 1345-line `Buffer.swift` | 4 |
| Each type in its own file, Buffer.swift references them | 0 |

**~~The file split alone eliminates the crash.~~** ← This result could not be reproduced with clean builds (`rm -rf .build`). See Step 6 for corrected findings.

However, cross-extension nested type visibility is limited in Swift 6.2 — `Small._Representation` references `Inline<inlineCapacity>` by unqualified name, which doesn't resolve when `Inline` is defined in a separate extension. The types need to be in **separate modules** (SPM targets) for proper cross-module type resolution, or the `Small` references need explicit module-qualified paths.

### Step 5: What does NOT cause the crash

Extensive elimination ruled out:

| Hypothesis | Result |
|-----------|--------|
| `@inlinable` on Buffer.Aligned methods | Not the cause — crash persists with all `@inlinable` removed |
| `Int(bitPattern: count.cardinal)` pattern | Not the cause — crash persists with typed API |
| `@inline(never)` preventing inlining | Does not help — crash is in the function bodies themselves |
| Cross-module optimization (CMO) | Not the cause — `-disable-cmo` still crashes |
| `deinit` on Buffer.Aligned | Not the cause — Buffer.Aligned has no `@_rawLayout` |
| Standalone reproducer (same types, local definitions) | Does not crash — requires the full dependency graph |

### Step 6: Implementation attempt and corrected findings (2026-03-20)

The file-split approach from Step 4 was attempted with exhaustive testing. Clean builds (`rm -rf .build`) produced different results than the original Step 4 investigation (which may have used incremental builds).

#### Corrected crash behavior

**All tests below used clean builds.**

##### Struct-body pattern (types defined inside the struct body in Buffer.swift)

| Condition | Errors |
|-----------|:------:|
| 0 deinits enabled (all 4 commented out) | 0 |
| 1 deinit enabled (any single type) | 0 |
| 2 deinits enabled (Ring + Slab) | 0 |
| All 4 deinits enabled | **2** |

**Finding**: In the struct-body pattern, the crash requires **3+ types** with @_rawLayout + deinit in the same WMO translation unit. The error count is always 2 regardless of having 3 or 4 triggering types.

##### Extension-file pattern (types defined via `extension Buffer.Ring { }` in separate files)

| Condition | Errors |
|-----------|:------:|
| 1 Inline type via extension (deinit enabled) | **2** |
| 1 Inline type via extension (deinit disabled) | 0 |
| 4 Inline types via extension (all deinits) | **2** |
| 4 Inline types via extension + 4 Small types in separate extension files | **2** |
| 4 Inline types via extension + 4 Small types co-located with Inline | **2** |

**Finding**: When a type with @_rawLayout + deinit is defined via extension in a separate file, even a **single type** triggers the crash. The extension-file pattern is strictly worse than the struct-body pattern.

##### Small type interaction

| Condition | Errors |
|-----------|:------:|
| Inline + Small in same extension file | **2** |
| Inline and Small in separate extension files | **2** |
| Inline in extension file, no Small anywhere | **2** |

**Finding**: The `Small._Representation` enum (whose implicit destructor touches @_rawLayout through Inline) is NOT the cause. The crash comes from the Inline type's own deinit, made worse by the extension-file pattern.

##### Cross-extension visibility

| Approach | Compiles? |
|----------|:---------:|
| Unqualified `Inline<inlineCapacity>` from struct body | **No** — `Element` does not conform to `Copyable` |
| Qualified `Buffer.Ring.Inline<inlineCapacity>` from struct body | **No** — same error |
| Unqualified `Inline<inlineCapacity>` from extension in different file | **Yes** |
| Qualified `Buffer.Ring.Inline<inlineCapacity>` from extension in different file | **Yes** |

**Finding**: Types added via extension ARE visible from other extension files in the same module. They are NOT visible from the original struct body. This is a Swift 6.2 limitation on cross-file nested type resolution.

##### Single-field wrapper (`_Fields`) approach

| Approach | Errors |
|----------|:------:|
| Wrap header + storage into `_Fields` struct (no deinit), Inline has 1 field + deinit | **2** |
| Original 2-field Inline with deinit | **2** |

**Finding**: The single-field wrapper does NOT help when the type is defined via extension. The crash is not sensitive to stored field count in the extension-file pattern.

##### WMO and non-WMO

| Mode | Errors |
|------|:------:|
| Release (WMO, `-O`) | **2** |
| Debug with `-Xswiftc -O` (no WMO, optimized) | **2** |
| Debug without `-O` | 0 |

**Finding**: The crash requires `-O` optimization but does NOT require WMO. It occurs in per-file compilation too. This invalidates the earlier hypothesis that WMO cross-type interaction was the cause.

#### Refined root cause

The crash is triggered by:

1. A `~Copyable` struct with `@_rawLayout` stored field(s)
2. An explicit **deinit** block on that struct
3. `-O` optimization enabled
4. Both `Storage_Primitives` and `Cyclic_Index_Primitives` visible (sufficient serialized SIL from the dependency graph)
5. **Threshold effect**: In the struct-body pattern, 3+ such types in the same compilation unit are required. In the extension-file pattern, even 1 type triggers the crash.

The "2+ stored fields" condition from v1.0 is **not confirmed** — the crash occurs regardless of field count when using the extension-file pattern.

#### What still works

The struct-body pattern with ≤2 types with @_rawLayout + deinit does NOT crash. This is the only confirmed safe configuration.

## Decision

### v1.0 decision (INVALIDATED)

~~Split Buffer.swift into per-type files per [API-IMPL-005].~~

The file-split approach does not fix the crash — it makes it worse by switching from the struct-body pattern to the extension-file pattern.

### v2.0 decision: OPEN — needs further investigation

Possible approaches (not yet validated):

1. **Reduce deinit count to ≤2 in the struct body**: Keep all types in Buffer.swift. Remove explicit deinits from 2 of the 4 Inline types and replace with an alternative cleanup mechanism (consuming `destroy()` method, or restructuring Storage.Inline to handle its own cleanup). Keeps the struct-body pattern where the threshold is 3+.

2. **Move type declarations to existing Inline SPM targets**: The package already has `Buffer Ring Inline Primitives`, `Buffer Linear Inline Primitives`, etc. Moving the type DECLARATIONS there (not just operations) gives each type its own WMO unit. **Blocker**: 26+ files across operation targets reference `Inline`/`Small`, creating circular dependencies or requiring extensive restructuring.

3. **Compiler bug report + `withKnownIssue`**: File a bug at swiftlang/swift with the minimal reproducer. Mark release tests with `withKnownIssue` until the fix lands.

### Phase 2: Typed API cleanup (independent improvement, unchanged)

Replace `Int` parameters in `Buffer.Aligned+Convenience.swift` with typed indices per [CONV-010]:
- `subscript(index: Int)` → `subscript(index: Index<UInt8>)`
- `copy(at offset: Int)` → `copy(at offset: Index<UInt8>)`
- `zero(range: Range<Int>)` → `zero(range: Range<Index<UInt8>>)`
- `Int(bitPattern: count.cardinal)` → `Int(bitPattern: count)` at stdlib boundaries

Replace `.rawValue` chains in `Buffer.Unbounded.swift` with clean `Int(bitPattern:)`.

### Phase 3: Compiler bug report

File at https://github.com/swiftlang/swift/issues with:
- Minimal trigger: `~Copyable` struct with `@_rawLayout` field + deinit + `-O` optimization + sufficient cross-module SIL
- Extension-file pattern crashes with even 1 type; struct-body pattern requires 3+
- The crash is in IRGen: `invariant.load` annotation on `let` stored property accesses gets mis-positioned relative to `@_rawLayout` destruction sequences

## Workarounds Considered

| Workaround | Status | Why |
|-----------|--------|-----|
| File split (same module, extension files) | **Does not work** | Extension-file pattern crashes with even 1 type |
| File split (same module, struct body) | N/A | Types can only be in one struct body (one file) |
| Separate SPM targets for type declarations | **Blocked** | 26+ cross-references in operation targets; circular deps |
| Enum `_StorageRepr` wrapping `@_rawLayout` field | Partial | Works for simple deinits, breaks `_modify` on enum payloads |
| `_Fields` single-field wrapper struct | **Does not work** | Extension-file pattern ignores field count |
| `@inline(never)` on all methods | Does not work | Crash is in IRGen, not inlining |
| Disabling CMO | Does not work | Bug is module-internal |
| Disabling WMO (`-no-whole-module-optimization`) | Does not work | Crash occurs in per-file `-O` compilation too |
| `-Xswiftc -no-whole-module-optimization` on CLI | Does not work | Same — crash is not WMO-dependent |

## Cross-References

- [small-buffer-enum-compiler-workarounds.md](small-buffer-enum-compiler-workarounds.md) — same LLVM verifier error, different trigger (two-field struct with @_rawLayout + class ref)
- [release-crash-fix-handoff.md](release-crash-fix-handoff.md) — handoff document (v1.0 approach, now invalidated)
- Experiment: `Experiments/rawlayout-release-verifier-crash/` — 30+ variants testing @_rawLayout patterns
- `/conversions` skill — typed API rules for the Phase 2 cleanup
- `/existing-infrastructure` skill — Cardinal integration overloads for stdlib boundary conversions
