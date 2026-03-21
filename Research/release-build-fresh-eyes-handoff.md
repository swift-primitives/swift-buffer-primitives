# Handoff: Release Build + SPM Compatibility — Fresh Eyes

## Your Mission

Find a way to make `swift build -c release` work for swift-buffer-primitives WITHOUT `.unsafeFlags` in Package.swift. Prebuilt binary distribution is not acceptable — the solution must be source-level.

Everything in this document has been tried and failed. Your job is to think outside the box. Read the constraints carefully, then find an angle we missed.

## The Two Compiler Bugs

**Bug 1 — LLVM Verifier Crash** ("Instruction does not dominate all uses!"):
- Signal 6 in LLVM `verify` pass under `-O`
- Trigger: `~Copyable` struct with `@_rawLayout` stored field + explicit `deinit` + release mode
- 4 types trigger it: `Buffer.Ring.Inline`, `Buffer.Linear.Inline`, `Buffer.Slab.Inline`, `Buffer.Arena.Inline`
- All defined via `extension` in Buffer Primitives Core module
- Filed: https://github.com/swiftlang/swift/issues/86652
- Standalone reproducer: `Experiments/rawlayout-minimal-reproducer/`

**Bug 2 — SIL Ownership Crash** ("Found ownership error?!"):
- Signal 6 in CopyPropagation SIL pass under `-O`
- Only appears when Bug 1 is suppressed via `-disable-llvm-verify`
- Affects 3 of 12 downstream modules: Ring Primitives, Ring Inline Primitives, Slab Inline Primitives
- Cannot be reproduced standalone (7 patterns tried, all failed)
- Context-sensitive — requires full production dependency graph

## Current Workaround (blocks SPM)

Package.swift uses two `.unsafeFlags`:
```swift
// On Buffer Primitives Core target:
.unsafeFlags(["-Xfrontend", "-disable-llvm-verify",
              "-Xfrontend", "-disable-sil-ownership-verifier"],
             .when(configuration: .release))

// On ALL other targets:
.unsafeFlags(["-Xfrontend", "-disable-sil-ownership-verifier"],
             .when(configuration: .release))
```

391 tests pass. Debug builds unaffected. The flags disable verification passes, not optimization — generated code is identical. But SPM blocks any package with `.unsafeFlags` from being used as a Git URL or registry dependency.

## What Has Been Tried (Exhaustive — All Failed)

### Code-level restructuring
| Approach | Result | Why |
|----------|--------|-----|
| Split into per-file extensions | Crashes | Extension-file pattern: 1 type triggers crash |
| Move types to variant SPM targets | Crashes | [MOD-004] Copyable constraint poisoning |
| Per-variant-family Core modules | Crashes | Cross-module extension: 1 type triggers crash |
| Standalone module for each Inline type | Crashes | Cross-module Buffer extension: threshold 0 |
| Same-file extension in Buffer.swift | Crashes | Compiler treats all extensions identically |
| Move Inline into Buffer's enum body | Crashes | Can't reference Ring.Header from Buffer's body |
| `_Fields` single-field wrapper struct | Crashes | Extension-file pattern ignores field count |

### Workaround patterns
| Approach | Result | Why |
|----------|--------|-----|
| `AnyObject? = nil` (triviality fix) | Crashes | Only fixes minimal reproducer, not production (extension-file under WMO) |
| Remove `@inlinable` from crashing functions | Crashes | WMO still optimizes all functions |
| `@_transparent` on crashing functions | N/A | Functions too complex (loops, switches) |
| `@_optimize(none)` on crashing functions | Whack-a-mole | New functions crash as each is fixed |
| `discard self` pattern | Blocked | @_rawLayout types not trivially destructible |
| Add deinit to Small types instead | 85+ errors | "cannot partially consume self when it has a deinitializer" |
| Disable CMO / WMO | Crashes | Bug is per-file under `-O`, not WMO-dependent |

### Deinit elimination
| Approach | Result | Why |
|----------|--------|-----|
| Remove Ring/Linear deinit (delegate to Storage.Inline) | Not tested | Slab/Arena deinits still crash (extension-file, even 1 type) |
| Remove ALL deinits | Leaks | Slab/Arena have custom cleanup logic (bitmap/meta-driven) |
| Comment out all Inline/Small types | Rejected | All variants used by 12+ downstream packages |

## The Root Cause

The compiler incorrectly classifies `@_rawLayout` types with generic-dependent layout as "trivially destructible" when imported cross-module. This causes:
- Bug 1: LLVM IR for the destructor has instructions that don't dominate their uses
- Bug 2: SIL ownership verifier sees a double-consume in CopyPropagation output

The `AnyObject?` workaround forces non-trivial classification, which fixes the simpler trigger path (consumer-module with 2+ fields). But the production code uses extension-defined types under WMO, which is a different LLVM IR lowering path that `AnyObject?` doesn't fix.

## The 4 Triggering Types

Read these files — they are the complete type definitions:

```
Sources/Buffer Primitives Core/Buffer.Ring.Inline.swift    — deinit { storage.deinitialize() }
Sources/Buffer Primitives Core/Buffer.Linear.Inline.swift  — deinit { storage.deinitialize() }
Sources/Buffer Primitives Core/Buffer.Slab.Inline.swift    — deinit { bitmap-driven iteration }
Sources/Buffer Primitives Core/Buffer.Arena.Inline.swift   — deinit { meta-driven iteration }
```

All 4 are `~Copyable` structs defined via `extension Buffer.X where Element: ~Copyable { ... }` and contain `Storage<Element>.Inline<capacity>` (which is `@_rawLayout` from swift-storage-primitives).

Arena.Inline additionally defines its own `@_rawLayout` struct `_Elements` inline.

## Key Constraints

1. All 4 Inline types must exist (used by 12+ downstream packages)
2. All 4 need element cleanup on destruction (elements would leak otherwise)
3. No `.unsafeFlags` in Package.swift (blocks SPM)
4. No prebuilt binary distribution
5. Must build with `swift build -c release`
6. `@_rawLayout` storage is non-negotiable (zero-overhead dense packing for `~Copyable` elements)
7. Toolchain: Swift 6.2.4 (Xcode, arm64 macOS 26)
8. Still broken on Swift 6.4-dev (main snapshot 2026-03-16)

## What You Should Read

In order:
1. This document (you're reading it)
2. The 4 Inline type files listed above
3. `Research/release-mode-llvm-verifier-crash-diagnosis.md` — Full 8-step diagnosis
4. `Research/release-build-options-v2.md` — Ranked options (all invalidated except flags)
5. `Experiments/rawlayout-minimal-reproducer/EXPERIMENT.md` — Standalone Bug 1 reproducer
6. `Experiments/rawlayout-llvm-verifier-crash/EXPERIMENT.md` — AnyObject? test results
7. `Package.swift` — Current flag workaround (lines 96-114, 364-371)

## What We Need From You

Think laterally. Every "obvious" approach has been tried. Consider:
- Compiler flag injection mechanisms that DON'T use `.unsafeFlags`
- SwiftPM build plugins or macros
- Alternative ways to express element cleanup without `deinit`
- Whether the cleanup logic can live at a different layer
- Whether `@_rawLayout` types can be structured differently while preserving zero-overhead
- Whether there's a way to make the LLVM verifier NOT crash without disabling it
- Whether the extension-file pattern can be avoided by restructuring how types are declared
- Anything else

The solution doesn't need to be pretty. It needs to work, be reversible when the compiler is fixed, and not use `.unsafeFlags`.
