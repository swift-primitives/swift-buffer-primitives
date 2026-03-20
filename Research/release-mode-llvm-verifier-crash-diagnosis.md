# Release Mode LLVM Verifier Crash: Root Cause Diagnosis

<!--
---
version: 4.0.0
last_updated: 2026-03-20
status: OPEN
decision: v1.0 file-split invalidated (Step 6). v2.0 move-to-variant invalidated by [MOD-004] constraint poisoning (Step 7). v3.0 per-variant-family Core modules invalidated by cross-module boundary effect (Step 8). All modularization approaches exhausted.
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

The struct-body pattern with ≤2 types with @_rawLayout + deinit does NOT crash. This is the only confirmed safe configuration **within the defining module** (see Step 8 for cross-module limitation).

### Step 7: Full modularization attempt and [MOD-004] constraint poisoning (2026-03-20)

Attempted full modularization: move ALL type definitions from Core into their respective variant modules (1 buffer variant per module). This was the v2.0 approach #2, taken to its logical conclusion.

#### What was attempted

1. Core stripped to 4 files: `Buffer.swift` (namespace), `Buffer.Growth.swift`, `Buffer.Growth.Policy.swift`, `exports.swift`
2. Type definitions moved to variant modules (e.g., `Buffer.Ring.swift` → Ring Primitives)
3. 10 new modules created: Ring Bounded, Ring Small, Linear Bounded, Slab Bounded, Slab Small, Linked Small, Arena Bounded, Arena Small, Aligned, Unbounded
4. Bounded/Small impl files moved from parent variant modules to their own modules
5. Cross-variant code split (e.g., `Buffer.Linear+forEach.swift` had extensions on Bounded/Inline/Small)

#### Empirical finding: [MOD-004] constraint poisoning

Moving type definitions to variant modules causes `type 'Element' does not conform to protocol 'Copyable'` on `Storage<Element>.Heap` stored properties.

**Root cause isolation** (binary search by file):

The trigger is `Copyable`-requiring protocol conformances in the **same module** as the type definition:

```swift
// In Buffer Ring Primitives — works alone:
extension Buffer where Element: ~Copyable {
    public struct Ring: ~Copyable {
        package var storage: Storage<Element>.Heap  // ← OK
    }
}

// Adding THIS to the same module poisons the type definition:
extension Buffer.Ring: Sequence.Drain.`Protocol` where Element: Copyable { ... }
```

The conformance `Buffer.Ring: Sequence.Drain.Protocol where Element: Copyable` makes the compiler propagate `Element: Copyable` to the struct's stored properties, breaking `Storage<Element>.Heap` which requires `Element: ~Copyable`.

**Verification matrix**:

| Configuration | Compiles? |
|---------------|:---------:|
| Type def alone (no conformances) | **Yes** |
| Type def + `where Element: ~Copyable` extensions | **Yes** |
| Type def + `where Element: ~Copyable` extensions + tag enums | **Yes** |
| Type def + `Sequence.Drain.Protocol where Element: Copyable` | **No** |
| Type def + `Sequence.Clearable where Element: Copyable` | **No** |

This is exactly what [MOD-004] predicts: "Constraint isolation is type-theoretically necessary, not merely pragmatic." The existing Core/variant split IS the constraint isolation boundary — Core holds type definitions with `~Copyable` support, variant modules add `Copyable`-requiring conformances in a separate module scope.

#### Conclusion

Type definitions **cannot** move to variant modules. The [MOD-004] constraint isolation between Core (type defs) and variant modules (conformances) is load-bearing.

### Step 8: Per-variant-family Core modules and cross-module boundary effect (2026-03-20)

The v3.0 approach: split monolithic Core into per-variant-family Core modules (`Buffer Ring Primitives Core`, `Buffer Linear Primitives Core`, etc.), each holding only type definitions with zero `Copyable`-requiring conformances. Each module has ≤2 `@_rawLayout` + `deinit` types, which should be safe per Step 6 struct-body findings.

#### What was attempted

1. Created 8 per-variant Core targets + root Core (4 files: namespace, growth, exports)
2. Moved all variant type files to their respective family Core modules
3. Merged Inline types into parent struct bodies (struct-body pattern) to avoid extension-file crash
4. All per-variant Core modules re-export root Core via `@_exported public import Buffer_Primitives_Core`
5. Updated all variant module exports and Package.swift dependencies
6. Debug build passes (`swift build`)

#### Empirical finding: cross-module boundary nullifies struct-body threshold

The struct-body threshold (≤2 types safe) from Step 6 only holds when the types are in the **same module as `Buffer`** (the namespace enum). When types extend `Buffer` from a different module — even with the Inline type in the parent's struct body — even **1 `@_rawLayout` + `deinit` type** triggers the crash.

**Test: Ring Core in isolation**

```
Buffer Ring Primitives Core (7 files):
├── Buffer.Ring.swift          ← Ring + Inline (deinit) in struct body
├── Buffer.Ring.Header.swift
├── Buffer.Ring.Bounded.swift
├── Buffer.Ring.Bounded.Error.swift
├── Buffer.Ring.Checkpoint.swift
├── Buffer.Ring.Small.swift
└── exports.swift              ← @_exported public import Buffer_Primitives_Core
```

| Configuration | Errors |
|---------------|:------:|
| Ring Core, full (all 7 files, Inline in struct body) | **2** |
| Ring Core, minimal (Ring+Inline+Header+exports only, other files emptied) | **2** |

**Critical comparison with Step 6**:

| Context | 1 @_rawLayout + deinit (struct-body) | Errors |
|---------|--------------------------------------|:------:|
| Same module as `Buffer` (monolithic Core) | Ring.Inline | 0 |
| Different module from `Buffer` (Ring Core) | Ring.Inline | **2** |

The cross-module extension boundary changes how the compiler generates IR for types extending `Buffer` from a separate module. The serialized SIL from `Storage_Primitives` and `Cyclic_Index_Primitives` (transitive dependencies) interacts differently when the extending type is in a separate compilation unit from the base namespace.

#### Root cause refinement

Condition 5 from Step 6 must be amended:

> 5. **Threshold effect**: ~~In the struct-body pattern, 3+ such types in the same compilation unit are required. In the extension-file pattern, even 1 type triggers the crash.~~ → The struct-body threshold (3+) only applies when the types are in the **same module** as the extended base type. When types extend a base type from a **different module** (cross-module extension), even 1 `@_rawLayout` + `deinit` type in struct-body pattern triggers the crash — same as the extension-file pattern.

#### Why this blocks all modularization approaches

The types MUST stay in the same module as `Buffer` (root Core) to benefit from the struct-body threshold. But root Core with 4 Inline types in struct-body pattern has 4 `@_rawLayout` + `deinit` types, exceeding the threshold of 3. Splitting types across modules loses the struct-body protection entirely.

This creates a fundamental constraint triangle:
1. **[MOD-004]**: Type definitions cannot be in the same module as `Copyable`-requiring conformances → Core/variant split is load-bearing
2. **Step 6**: ≤2 `@_rawLayout` + `deinit` types in struct-body in the same module → safe
3. **Step 8**: Cross-module extension nullifies the struct-body threshold → types MUST be in the same module as `Buffer`

Constraint (3) forces all types into root Core. Constraint (2) limits root Core to ≤2 `@_rawLayout` + `deinit` types. But we have 4. There is no modularization-based solution.

## Decision

### v1.0 decision (INVALIDATED)

~~Split Buffer.swift into per-type files per [API-IMPL-005].~~

The file-split approach does not fix the crash — it makes it worse by switching from the struct-body pattern to the extension-file pattern.

### v2.0 decision (INVALIDATED)

~~Move type declarations to variant SPM targets.~~

[MOD-004] constraint poisoning: `Copyable`-requiring conformances (`Sequence.Drain.Protocol`, `Sequence.Clearable`, `Collection.Protocol`) in the same module as type definitions that use `Storage<Element>.Heap where Element: ~Copyable` causes the compiler to propagate `Copyable` to stored properties. Type definitions MUST be in a separate module from conformances.

### v3.0 decision (INVALIDATED)

~~Split monolithic Core into per-variant-family Core modules.~~

Cross-module boundary effect (Step 8): when types extend `Buffer` from a different module, even 1 `@_rawLayout` + `deinit` type in struct-body pattern triggers the crash. The struct-body threshold (≤2 safe) only applies within the defining module. All modularization approaches are blocked by the constraint triangle (see Step 8).

### v4.0 decision: OPEN — non-modularization approaches required

All modularization strategies have been exhausted. Remaining approaches:

1. **Reduce deinit count to ≤2 in root Core**: Keep all types in monolithic `Buffer.swift` (struct-body pattern, same module as `Buffer`). Remove explicit deinits from 2 of the 4 Inline types and move cleanup to a consuming `deinitialize()` method or restructure `Storage.Inline` to manage its own element lifecycle. This stays within the struct-body threshold.

2. **Compiler bug report + `withKnownIssue`**: File at swiftlang/swift with the minimal reproducer. Mark release tests with `withKnownIssue` until fixed. Ship debug-only builds.

3. **Deinit-free Inline types**: Redesign ALL 4 Inline types to not have explicit deinits. Delegate element cleanup to consumers or to `Storage.Inline` itself (would require `Storage.Inline` to track initialization state and handle cleanup in its own `deinit`). Eliminates the trigger entirely.

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
| Move type defs to variant SPM targets | **Does not work** | [MOD-004] constraint poisoning — `Copyable` conformances poison `Storage<Element>.Heap` |
| Per-variant-family Core modules | **Does not work** | Cross-module boundary nullifies struct-body threshold (Step 8) |
| Per-variant Core with struct-body Inline | **Does not work** | Same — cross-module extension triggers crash with even 1 type |
| Enum `_StorageRepr` wrapping `@_rawLayout` field | Partial | Works for simple deinits, breaks `_modify` on enum payloads |
| `_Fields` single-field wrapper struct | **Does not work** | Extension-file pattern ignores field count |
| `@inline(never)` on all methods | Does not work | Crash is in IRGen, not inlining |
| Disabling CMO | Does not work | Bug is module-internal |
| Disabling WMO (`-no-whole-module-optimization`) | Does not work | Crash occurs in per-file `-O` compilation too |
| `-Xswiftc -no-whole-module-optimization` on CLI | Does not work | Same — crash is not WMO-dependent |

## Cross-References

- [small-buffer-enum-compiler-workarounds.md](small-buffer-enum-compiler-workarounds.md) — same LLVM verifier error, different trigger (two-field struct with @_rawLayout + class ref)
- [release-crash-fix-handoff.md](release-crash-fix-handoff.md) — handoff document (v1.0 approach, now invalidated)
- [per-variant-core-split-instructions.md](per-variant-core-split-instructions.md) — v3.0 implementation instructions (invalidated by Step 8)
- Experiment: `Experiments/rawlayout-release-verifier-crash/` — 30+ variants testing @_rawLayout patterns
- `/conversions` skill — typed API rules for the Phase 2 cleanup
- `/existing-infrastructure` skill — Cardinal integration overloads for stdlib boundary conversions
- `/modularization` skill — [MOD-004] constraint isolation theory confirmed empirically in Step 7
