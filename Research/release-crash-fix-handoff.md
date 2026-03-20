# Handoff: Fix Release Mode Compiler Crash

## Goal

Make `swift build -c release` and `swift test -c release` pass for swift-buffer-primitives (and by extension the entire ecosystem, since buffer-primitives is a transitive dependency).

## Current State

- **Working directory**: `/Users/coen/Developer/swift-primitives/swift-buffer-primitives`
- **Branch**: `three-layer-rewrite`
- **Buffer.swift**: Restored to clean state (commit `0b9739a`). Direct stored properties, no enum workarounds. The two later commits (`2303eb7` WIP, `8206155` Save progress) contain accidental enum workaround code that should be reverted.
- **Crash**: `swift build -c release --target "Buffer Primitives Core"` produces 4 "Instruction does not dominate all uses!" LLVM verifier errors (signal 6)
- **Debug builds work fine**: `swift build` succeeds

## Root Cause (Proven)

Read `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Research/release-mode-llvm-verifier-crash-diagnosis.md` for full analysis. Summary:

The crash requires ALL of:
1. `~Copyable` struct with 2+ stored fields where at least one contains `@_rawLayout`
2. Explicit `deinit` on that struct
3. Both `Storage_Primitives` and `Cyclic_Index_Primitives` imported (re-exported via `exports.swift`)
4. All in the **same source file** — splitting into separate files eliminates the crash

The 4 crashing types are `Buffer.Ring.Inline`, `Buffer.Linear.Inline`, `Buffer.Slab.Inline`, `Buffer.Arena.Inline` — all in `Sources/Buffer Primitives Core/Buffer.swift` (1345 lines).

## Proven Fix

**Splitting the 4 Inline types into separate files eliminates the crash with zero code changes.** This was tested empirically: same code, separate files → 0 LLVM verifier errors.

However, there is a visibility issue: the `Small` types reference `Inline` by unqualified name in their `_Representation` enum:
```swift
case inline(Inline<inlineCapacity>)
```
When `Inline` moves to a separate extension in a separate file, Swift can't resolve the unqualified name. Full path qualification (`Buffer<Element>.Ring.Inline<inlineCapacity>`) also fails — "not a member type."

## Recommended Approach

### Option A: Separate SPM targets (modules)

Move each Inline type to its own SPM target. Cross-module type resolution works. The `Small` types import the inline module and reference the type with the module-qualified name.

This aligns with [MOD-001] modularization and [API-IMPL-005] one-type-per-file. The buffer-primitives package already has ~20 targets.

### Option B: Keep same module, restructure nesting

Instead of defining `Inline` as a nested type added via extension, define it at the top level and typealias into the namespace. Swift resolves typealiases across file boundaries.

### Option C: Keep same module, use forward reference

The `Small._Representation` enum references `Inline`. If `Small` itself is also moved to a separate file (or the same file as `Inline`), the unqualified name resolves because they share the same extension scope.

## What NOT to Do

- **Don't apply enum `_StorageRepr` workarounds** — these were tried extensively and create problems: `_modify` doesn't work on enum payloads when the type has a deinit, which breaks mutating access to storage. The file split is the clean fix.
- **Don't add `@inline(never)`** — doesn't help. The crash is in IRGen, not inlining.
- **Don't disable CMO** — doesn't help. The bug is module-internal.

## Verification

After the fix, run:
```bash
cd /Users/coen/Developer/swift-primitives/swift-buffer-primitives
swift build -c release          # must produce 0 "Instruction does not dominate" errors
swift test -c release           # must not crash
```

Then from the superrepo:
```bash
cd /Users/coen/Developer/swift-primitives
swift build -c release          # ecosystem-wide verification
```

## Secondary Task (Independent)

Typed API improvements on `Buffer.Aligned` — see the research document's Phase 2 section. This is architecturally correct but does NOT fix the crash. Can be done in a separate pass. Key changes:
- `Int` parameters → typed `Index<UInt8>` per `/conversions` skill
- `Int(bitPattern: count.cardinal)` → `Int(bitPattern: count)` per `/existing-infrastructure` skill [INFRA-020]
- `.rawValue` chain cleanup in `Buffer.Unbounded.swift`

## Key Files

| File | Role |
|------|------|
| `Sources/Buffer Primitives Core/Buffer.swift` | 1345-line monolith containing all type declarations — needs splitting |
| `Sources/Buffer Primitives Core/exports.swift` | Re-exports that trigger the crash when combined |
| `Package.swift` | Target definitions — needs new targets if using Option A |
| `Research/release-mode-llvm-verifier-crash-diagnosis.md` | Full diagnosis with all experiments |
| `Research/small-buffer-enum-compiler-workarounds.md` | Prior related research |
| `Experiments/rawlayout-release-verifier-crash/` | Existing experiment with 30+ variants |
