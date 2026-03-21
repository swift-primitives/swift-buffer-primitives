# Handoff: Release Mode LLVM Verifier Crash Resolution

## Your Mission

Fix the `swift build -c release` crash in swift-buffer-primitives. This is an LLVM verifier crash ("Instruction does not dominate all uses!") triggered by `~Copyable` structs with `@_rawLayout` stored fields + explicit `deinit` under `-O` optimization. The crash blocks release builds across the entire Swift Institute ecosystem because buffer-primitives is a transitive dependency of everything.

You will first use `/experiment-process` to empirically validate the crash conditions and constraint triangle documented below, then iterate on solutions.

## Essential Context

### Read These First (in order)

1. **Full diagnosis** (v4.0.0 — 8 steps of investigation):
   `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Research/release-mode-llvm-verifier-crash-diagnosis.md`

2. **Failed v3.0 implementation** (per-variant Core split — invalidated by Step 8):
   `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Research/per-variant-core-split-instructions.md`

3. **Current Package.swift** (target structure, dependencies):
   `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Package.swift`

4. **The 4 triggering types** (read each file):
   - `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Sources/Buffer Primitives Core/Buffer.Ring.Inline.swift`
   - `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Sources/Buffer Primitives Core/Buffer.Linear.Inline.swift`
   - `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Sources/Buffer Primitives Core/Buffer.Slab.Inline.swift`
   - `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Sources/Buffer Primitives Core/Buffer.Arena.Inline.swift`

5. **The namespace definition**:
   `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Sources/Buffer Primitives Core/Buffer.swift`
   — `Buffer` is `public enum Buffer<Element: ~Copyable> {}` (namespace enum)

6. **Storage.Inline** (the @_rawLayout type used by all 4 Inline buffers):
   Find `Storage.Inline` in `/Users/coen/Developer/swift-primitives/swift-storage-primitives/` — this is where `@_rawLayout` and the `deinitialize()` method live.

### The Crash in 30 Seconds

- **What**: `swift build -c release` → signal 6, "Instruction does not dominate all uses!" in LLVM verifier
- **Where**: `Buffer Primitives Core` module (tier 15, transitive dep of everything)
- **Trigger**: `~Copyable` struct + `@_rawLayout` stored field + explicit `deinit` + `-O` optimization + sufficient cross-module serialized SIL from `Storage_Primitives` + `Cyclic_Index_Primitives`
- **4 triggering types**: `Buffer.Ring.Inline`, `Buffer.Linear.Inline`, `Buffer.Slab.Inline`, `Buffer.Arena.Inline`
- **Toolchain**: Swift 6.2.4 (Xcode, arm64 macOS 26)

### The Constraint Triangle (Why Modularization Fails)

Three constraints make all modularization approaches impossible:

1. **[MOD-004] Constraint Isolation** (Step 7): Type definitions using `Storage<Element>.Heap where Element: ~Copyable` CANNOT be in the same module as `Copyable`-requiring protocol conformances (`Sequence.Drain.Protocol`, `Collection.Protocol`, etc.). The compiler propagates `Copyable` from the conformance to stored properties. This means the Core/variant module split is load-bearing — types stay in Core, conformances stay in variant modules.

2. **Struct-body Threshold** (Step 6): In the same module as `Buffer`, types with `@_rawLayout` + `deinit` defined in the parent's struct body (same file) are safe if ≤2 such types exist. 3+ triggers the crash. The extension-file pattern (separate files) crashes with even 1 type.

3. **Cross-module Boundary Effect** (Step 8): When types extend `Buffer` from a DIFFERENT module (any per-variant Core, any split), even 1 `@_rawLayout` + `deinit` type in struct-body pattern triggers the crash. The struct-body threshold only holds within the defining module.

**Result**: Types must stay in root Core (constraint 3). Root Core is limited to ≤2 deinits in struct-body (constraint 2). We have 4. No modularization solution exists.

### What Has Been Tried and Failed

| Approach | Step | Why It Failed |
|----------|------|---------------|
| Split Buffer.swift into per-type files | 6 | Extension-file pattern crashes with even 1 type |
| Move type defs to variant SPM targets | 7 | [MOD-004] constraint poisoning |
| Per-variant-family Core modules | 8 | Cross-module boundary nullifies struct-body threshold |
| Struct-body Inline in per-variant Core | 8 | Same — cross-module extension triggers crash |
| `_StorageRepr` enum wrapping @_rawLayout | 6 | Breaks `_modify` on enum payloads |
| `_Fields` single-field wrapper struct | 6 | Extension-file pattern ignores field count |
| `@inline(never)` on all methods | 5 | Crash is in IRGen, not inlining |
| Disabling CMO / WMO | 5,6 | Crash is per-file under `-O`, not WMO-dependent |

### Existing Worktree (v3.0 implementation — for reference only)

The per-variant Core split was fully implemented in a worktree:
`/Users/coen/Developer/swift-primitives/swift-buffer-primitives-modularization/`
Branch: `per-variant-core-split` (2 commits)

This builds in debug but crashes in release. It is reference material showing the module structure that would be ideal IF the compiler bug didn't exist. Do NOT continue working in this worktree — work from the main checkout.

## Phase 1: Experiment — Validate the Constraint Triangle

Use `/experiment-process` to create a controlled experiment that validates the 3 constraints.

### Experiment Location

`/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Experiments/constraint-triangle-validation/`

### What to Validate

#### Experiment 1: Struct-body threshold in defining module

Working directory: `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/`

In root Core (where `Buffer` is defined), test the struct-body threshold by modifying `Buffer.swift` to re-inline the Inline types:

1. Take the current monolithic `Buffer.swift` (if it still exists as a 1345-line file) OR reconstruct by inlining the 4 Inline type definitions back into their parent struct bodies within one file
2. Enable 0, 1, 2, 3, 4 deinits systematically (comment/uncomment)
3. Clean build (`rm -rf .build`) + `swift build -c release --target "Buffer Primitives Core"` for each
4. Record error counts

**Expected**: 0 errors for ≤2 deinits, 2 errors for 3-4 deinits (confirms Step 6)

#### Experiment 2: Cross-module boundary effect

1. Create a minimal per-variant Core module with ONLY 1 type (`Buffer.Ring` + `Buffer.Ring.Inline` in struct body) + exports
2. Clean build in release
3. Compare: same type in root Core (struct body) vs. per-variant Core (cross-module extension)

**Expected**: 0 errors in root Core, 2 errors in per-variant Core (confirms Step 8)

#### Experiment 3: Deinit removal feasibility

For each of the 4 Inline types, test:
1. Comment out the `deinit` block entirely
2. Verify the module compiles in release
3. Check: does `Storage<Element>.Inline` have its own cleanup mechanism? Read the Storage.Inline implementation.

**Expected**: 0 errors with all deinits removed. Need to understand if Storage.Inline can handle cleanup autonomously.

### Experiment Protocol

For each experiment:
- Always `rm -rf .build` before each test (incremental builds give false results)
- Record the EXACT command, the EXACT file modifications, and the EXACT output
- Use `swift build -c release --target "Buffer Primitives Core" 2>&1 | grep -c "Instruction does not dominate"` to count errors
- Document in the experiment directory per `/experiment-process` skill

## Phase 2: Iterate on Solutions

Based on experiment results, pursue the most promising approach. The candidates, ordered by likely feasibility:

### Candidate A: Deinit-Free Inline Types (Preferred if feasible)

**Hypothesis**: If `Storage<Element>.Inline` already tracks initialization state (it uses a per-slot bitvector), it might be able to handle element cleanup in its own `deinit` — making the explicit `deinit` on the Inline buffer types unnecessary.

**Investigation**:
1. Read `Storage<Element>.Inline` implementation in `swift-storage-primitives`
2. Check if `Storage.Inline` has a `deinit` that deinitializes elements using its bitvector
3. If yes: remove all 4 Inline buffer deinits → crash eliminated
4. If no: can `Storage.Inline` be enhanced to do this? What are the implications?

**Key concern**: `Buffer.Slab.Inline` and `Buffer.Arena.Inline` have DIFFERENT cleanup logic than Ring/Linear:
- Ring/Linear: `unsafe storage.deinitialize()` — delegates to Storage.Inline
- Slab: bitmap-driven iteration using `header.bitmap` (NOT storage's bitvector)
- Arena: meta-driven iteration using `_meta[i].isOccupied` with raw pointer arithmetic

So even if Storage.Inline handles Ring/Linear cleanup, Slab and Arena need different approaches.

### Candidate B: Reduce to ≤2 Deinits in Struct Body

**Approach**: Keep 2 of the 4 Inline deinits (e.g., Slab + Arena which have complex cleanup), remove the other 2 (Ring + Linear which just call `storage.deinitialize()`), and have Storage.Inline handle Ring/Linear cleanup.

**Steps**:
1. Verify Storage.Inline can clean up initialized elements on its own
2. Remove `deinit` from `Buffer.Ring.Inline` and `Buffer.Linear.Inline`
3. Keep `deinit` on `Buffer.Slab.Inline` and `Buffer.Arena.Inline`
4. Re-inline all 4 types into one `Buffer.swift` (struct-body pattern)
5. 2 deinits in struct-body in defining module → should be 0 errors

**Risk**: Slab.Inline's deinit uses `header.bitmap` (not storage's bitvector) for cleanup. Arena.Inline uses `_meta` for cleanup. These are fundamentally different from Storage.Inline's own tracking. Having 2 deinits should still be within threshold, but verify experimentally.

### Candidate C: Single Monolithic File with Deinit Workaround

**Approach**: Keep all types in one `Buffer.swift` but find a way to express the cleanup logic without `deinit`.

**Ideas**:
- `consuming func destroy()` pattern: caller explicitly destroys before drop
- `borrowing func withCleanup(_ body: () -> Void)` wrapper
- Encode cleanup into the storage type itself via protocol witness

**Risk**: Breaks the RAII contract. Consumers must remember to call `destroy()`. Leaks if they don't.

### Candidate D: Compiler Bug Report + Workaround

**Approach**: File the bug, mark release tests with `withKnownIssue`, and keep the monolithic `Buffer.swift` with 4 deinits (crashes in release but works in debug).

**Steps**:
1. Create minimal reproducer package (no ecosystem deps)
2. File at https://github.com/swiftlang/swift/issues
3. Add `withKnownIssue` to all release-mode tests
4. Document the workaround timeline

**Risk**: Blocks all release builds indefinitely. Acceptable only as a stopgap.

## Constraints and Ground Rules

- **Build from main checkout**: `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/` on branch `three-layer-rewrite`
- **Clean builds only**: Always `rm -rf .build` before release build tests. Incremental builds give false results.
- **Do not modify the worktree**: `/Users/coen/Developer/swift-primitives/swift-buffer-primitives-modularization/` is reference only
- **Verify each finding against current code before acting on it** — the diagnosis document records findings at a point in time; code may have changed
- **Typed throws required**: All throwing functions use typed throws per [API-ERR-001]
- **No Foundation**: Primitives packages never import Foundation per [PRIM-FOUND-001]
- **Challenge implementations**: If you see issues with the approach, say so directly. Do not rubber-stamp.

## Success Criteria

1. `swift build` passes (debug) — already works, must not regress
2. `swift build -c release` passes — **the primary goal**
3. `swift test` passes (debug)
4. No `Copyable`-requiring conformances in Core (preserves [MOD-004])
5. All 4 Inline buffer types still have correct element cleanup semantics (no leaks)
6. Solution is documented with empirical evidence from experiments

## Quick Reference: Key Paths

| What | Path |
|------|------|
| Package root | `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/` |
| Core sources | `.../Sources/Buffer Primitives Core/` |
| Diagnosis doc | `.../Research/release-mode-llvm-verifier-crash-diagnosis.md` |
| v3.0 instructions | `.../Research/per-variant-core-split-instructions.md` |
| Storage.Inline | `/Users/coen/Developer/swift-primitives/swift-storage-primitives/` (search for `Storage.Inline`) |
| Consolidated experiments | `.../Experiments/rawlayout-llvm-verifier-crash/` (V01-V08), `rawlayout-sil-ownership-crash/` (V01-V03), `rawlayout-deinit-alternatives/` (V01-V04) |
| Worktree (ref only) | `/Users/coen/Developer/swift-primitives/swift-buffer-primitives-modularization/` |
