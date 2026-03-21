# Handoff: Release Build Resolution v2 — Explore Consolidated Experiments

## Your Mission

Using the consolidated experiment corpus, find a path to `swift build -c release` that:
1. Compiles without compiler flags (`-disable-llvm-verify`, `-disable-sil-ownership-verifier`)
2. Does NOT infect downstream consumers
3. Preserves element cleanup for all 4 Inline types (no leaks)

If no clean solution exists, produce a RANKED list of options with their trade-offs, and build a minimal reproducer package for filing against swiftlang/swift.

## Essential Context

### Read These First (in order)

1. **Full diagnosis** (v3.0.0):
   `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Research/release-mode-llvm-verifier-crash-diagnosis.md`

2. **Original resolution handoff** (v1, documents the constraint triangle):
   `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Research/release-crash-resolution-handoff.md`

3. **Current Package.swift** (has workaround flags):
   `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Package.swift`

### The Two Compiler Bugs

**Bug 1 — LLVM verifier crash** ("Instruction does not dominate all uses!"):
- Trigger: `~Copyable` struct + `@_rawLayout` stored field + explicit `deinit` + `-O`
- Threshold varies by module and pattern:
  - Extension-file: 1 type crashes
  - Struct-body (parent without class ref): ≤2 types OK, 3+ crashes
  - Struct-body (parent WITH class ref like Storage.Heap): 1 type crashes
  - Same-file extension (extension in same .swift as parent): same as extension-file, crashes with 1
  - Cross-module extension: 1 type crashes
  - Storage Primitives Core: threshold 0 (even 1 struct-body type crashes)

**Bug 2 — SIL ownership crash** ("Found ownership error?!"):
- Trigger: `@_rawLayout` types in serialized SIL → CopyPropagation pass under `-O`
- Pre-existing: happens WITH all 4 deinits intact (not caused by removing deinits)
- Was masked by Bug 1 preventing Core from building
- Affects specific downstream modules: Ring Primitives, Ring Inline Primitives, Slab Inline Primitives
- Other downstream modules (Linear, Arena, Linked, Slots) unaffected

### What Has Been Tried (Exhaustive)

| Approach | Result | Why it failed |
|----------|--------|---------------|
| Split into per-file extensions | Crashes | Extension-file pattern: 1 type triggers crash |
| Move types to variant SPM targets | Crashes | [MOD-004] Copyable constraint poisoning |
| Per-variant-family Core modules | Crashes | Cross-module extension: 1 type triggers crash |
| Slab+Arena struct-body, Ring+Linear no deinit | Core passes, 3 downstream crash | SIL ownership crash (Bug 2) in Ring Primitives, Ring Inline, Slab Inline |
| Ring+Linear struct-body, Slab+Arena no deinit | Core crashes | Ring's parent stores Storage.Heap (class ref) → struct-body blocked |
| Ring.Inline in Buffer's enum body | Core crashes | Can't reference Ring.Header from Buffer's body (cross-extension visibility) |
| Same-file extension in Buffer.swift | Core crashes | Compiler treats all extensions identically |
| Add deinit to Storage.Inline | Crashes storage-primitives | Threshold 0 in Storage Primitives Core |
| Add deinit to Small types | 85+ compile errors | "cannot partially consume self when it has a deinitializer" |
| Standalone module (Ring Inline Core) | Crashes | Cross-module Buffer extension: threshold 0 |
| `-disable-llvm-verify` + `-disable-sil-ownership-verifier` | Builds, 391 tests pass | Requires flags; downstream may need SIL flag |
| `@_optimize(none)` on crashing functions | Whack-a-mole | New functions crash as each is fixed |

### Current Workaround State

Package.swift has:
- `-Xfrontend -disable-llvm-verify` on Buffer Primitives Core target (release only)
- `-Xfrontend -disable-sil-ownership-verifier` on all targets (release only)

All 4 Inline types retain their original deinits. 391 tests pass. Debug build unaffected.

**Problem**: `.unsafeFlags` blocks registry distribution. Downstream consumers may need the SIL flag.

## Your Task: Explore the Consolidated Experiments

### Step 1: Read ALL experiment manifests

Read the EXPERIMENT.md for each consolidated experiment:

```
swift-buffer-primitives/Experiments/rawlayout-llvm-verifier-crash/EXPERIMENT.md
swift-buffer-primitives/Experiments/rawlayout-sil-ownership-crash/EXPERIMENT.md
swift-buffer-primitives/Experiments/rawlayout-deinit-alternatives/EXPERIMENT.md
```

Each has per-variant documentation with exact build commands, expected vs actual results, and which diagnosis finding it supports.

### Step 2: Run each experiment variant in release mode

For each variant in each experiment, do a clean release build and record whether the result matches the documented finding. The experiments are self-contained packages.

```bash
cd <experiment>/
rm -rf .build && swift build -c release 2>&1 | tail -10
```

Document any DISCREPANCIES between documented and actual results — the experiments were written from prior findings, not freshly validated.

### Step 3: Explore paths not yet tested

The experiments document what WAS tested. Look for gaps — configurations or patterns that weren't tried. Specifically:

#### 3a: Investigate the SIL crash trigger

Bug 2 hits 3 of 12 downstream modules. WHY those 3? What's special about `Ring.arrayLiteral`, `Ring Inline` conformances, and `Slab.Small.drain`?

- Read the specific @inlinable functions that crash
- Check: do they reference @_rawLayout types at all? (arrayLiteral doesn't use Ring.Inline)
- Check: is the crash in the function's OWN SIL or in inlined SIL from Core?
- Check: does removing `@inlinable` from just those functions prevent the crash without affecting other modules?

#### 3b: Test non-@inlinable as a targeted fix

Unlike `@_optimize(none)` (which still serializes SIL), removing `@inlinable` prevents the function's SIL from triggering CopyPropagation issues. Test:

1. Remove `@inlinable` from `Buffer.Ring.arrayLiteral`
2. Remove `@inlinable` from crashing functions in Ring Inline Primitives
3. Remove `@inlinable` from `Buffer.Slab.Small.drain`
4. Build ALL targets in release WITHOUT any compiler flags
5. If new functions crash: how many? Is it bounded?

The trade-off: non-@inlinable functions can't be inlined by consumers (performance cost). But if it's only 3-5 functions, the performance impact may be acceptable.

#### 3c: Test `@_transparent` vs `@inlinable`

`@_transparent` functions are always inlined at the call site and don't go through the SIL optimizer pipeline the same way. Does making the crashing functions `@_transparent` avoid the CopyPropagation crash while preserving inlining?

#### 3d: Investigate whether the SIL crash is a false positive

The SIL ownership verifier catches what it thinks is an error. Is the SIL actually INCORRECT, or is the verifier too strict for @_rawLayout types?

- Extract the SIL for the crashing function: `swift build -c release -Xswiftc -emit-sil 2>&1 | head -500`
- Look at the ownership pattern around @_rawLayout destruction
- If the SIL is actually correct: the fix is in the verifier, not our code

#### 3e: Test reducing @_rawLayout surface

What if Ring.Inline and Linear.Inline DON'T use `Storage<Element>.Inline` at all, but instead use a simpler raw storage approach that doesn't trigger the bugs?

For example: `InlineArray<capacity, Optional<Element>>` — uses Optional for uninitialized slots, no @_rawLayout needed. Trade-off: requires `Element: Copyable` for Optional, wastes space for the Optional tag.

Or: Use `ManagedBuffer` for inline-like semantics (heap-allocated but single-allocation). Loses the "inline" (stack-allocated) property entirely.

#### 3f: Test whether the threshold is compiler-version-dependent

If you can access Swift nightly or a different toolchain:
```bash
TOOLCHAINS=org.swift.xxxxx swift build -c release
```
The bugs might already be fixed in trunk.

### Step 4: Build a minimal reproducer

Regardless of whether a code-level fix is found, create a MINIMAL standalone package that reproduces both bugs. This is needed for filing against swiftlang/swift.

Requirements:
- Single Package.swift, no external dependencies
- Reproduces Bug 1: @_rawLayout + deinit + -O → LLVM verifier crash
- Reproduces Bug 2: @_rawLayout serialized SIL → CopyPropagation ownership crash
- Include instructions to build and observe each bug independently

The diagnosis notes that standalone reproducers with local definitions DON'T crash — you need cross-module serialized SIL. So the reproducer package needs at least 2 modules:

```
Module A: defines @_rawLayout types with deinit
Module B: imports Module A, has @inlinable functions → triggers Bug 2
```

For Bug 1, Module A alone should crash with 3+ @_rawLayout+deinit types.

Place the reproducer at:
`/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Experiments/rawlayout-minimal-reproducer/`

### Step 5: Produce a ranked options document

Write a concise options document at:
`/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Research/release-build-options-v2.md`

For each option, document:
1. **What**: one-sentence description
2. **Correctness**: does element cleanup work for all types?
3. **Downstream impact**: do consumers need flags or changes?
4. **Performance**: any regression?
5. **Reversibility**: how easy to undo when compiler is fixed?
6. **Evidence**: which experiment variant validates it?

## Constraints

- Build from: `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/` on branch `three-layer-rewrite`
- Clean builds only: `rm -rf .build` before each release test
- Do NOT modify production source files — only experiment directories
- Toolchain: Swift 6.2.4 (Xcode, arm64 macOS 26)
- Always verify findings against current code before synthesizing

## Success Criteria

1. Every experiment variant validated (documented result matches actual)
2. Steps 3a-3f explored with empirical results
3. Minimal reproducer package created and verified
4. Ranked options document with evidence-backed recommendations
