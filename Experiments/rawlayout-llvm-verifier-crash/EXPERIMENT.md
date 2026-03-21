# @_rawLayout LLVM Verifier Crash Investigation

<!--
---
status: CONFIRMED (compiler bug)
date: 2026-03-21
toolchain: Swift 6.2.4 (Xcode, arm64 macOS 26)
consolidation_of:
  - swift-buffer-primitives/Experiments/rawlayout-release-verifier-crash/
  - swift-storage-primitives/Experiments/rawlayout-deinit-investigation/
  - swift-storage-primitives/Experiments/rawlayout-deinit-incremental/
  - swift-storage-primitives/Experiments/rawlayout-deinit-crossmodule/
  - swift-storage-primitives/Experiments/rawlayout-wrapper-validation/
  - swift-storage-primitives/Experiments/rawlayout-noncopyable-elements/
  - swift-buffer-primitives/Experiments/cross-module-type-declaration/
supports: release-mode-llvm-verifier-crash-diagnosis.md (Steps 1-8)
---
-->

## Question

Under what conditions does `~Copyable` struct + `@_rawLayout` stored field + explicit `deinit` crash the LLVM verifier under `-O` optimization?

## Summary

The crash requires the **combination** of: (1) `~Copyable` struct with `@_rawLayout` stored field(s), (2) explicit `deinit` block, (3) `-O` optimization, (4) sufficient cross-module serialized SIL from imported dependencies. Standalone reproducers with local type definitions do NOT crash — the bug is context-sensitive per [EXP-004a].

### Constraint Triangle (from diagnosis Steps 6-8)

1. **Struct-body threshold**: In the defining module, ≤2 types with `@_rawLayout` + `deinit` in the parent struct body → OK. 3+ → crash.
2. **Extension-file pattern**: Types via `extension` in separate files (or same file) → even 1 type crashes.
3. **Cross-module boundary**: Types extending a parent from a DIFFERENT module → even 1 type in struct-body crashes. Struct-body threshold only holds within the defining module.

### Workaround

`-Xfrontend -disable-llvm-verify` on Core target + `-Xfrontend -disable-sil-ownership-verifier` on all targets (release only). 391 tests pass.

## Variants

| Variant | Tests | Expected | Actual | Supports |
|---------|-------|----------|--------|----------|
| V01-baseline | Minimal @_rawLayout + deinit types, standalone | No crash | No crash (REFUTED in isolation) | Step 5: standalone doesn't reproduce |
| V02-struct-body-threshold | 1, 2, 3 types in struct body with real deps | ≤2 OK, 3+ crash | Cannot reproduce standalone | Step 6: struct-body ≤2 threshold |
| V03-extension-file | Types via extension, same or separate files | Even 1 crashes | Cannot reproduce standalone | Step 6: extension-file pattern |
| V04-cross-module | Types in separate module extending parent | Even 1 crashes | Cannot reproduce standalone | Step 8: cross-module boundary |
| V05-class-ref-interaction | Storage.Heap (class) + @_rawLayout in same type | Interaction with crash | Cannot reproduce standalone | New finding: Ring.Inline blocked by class ref |
| V06-wrapper-patterns | _Fields wrapper, single-field wrapper | Wrapper doesn't help | No crash standalone | Step 6: field count irrelevant in extension-file |
| V07-noncopyable-elements | @_rawLayout with ~Copyable elements | Works fine | CONFIRMED — works | Eliminates ~Copyable elements as cause |
| V08-storage-inline-deinit | Real Storage.Inline from pre-compiled package | Deinit not called | CONFIRMED — deinit skipped | Compiler bug: pre-compiled @_rawLayout deinit |

### New Session Findings (2026-03-20)

1. **Storage Primitives Core threshold 0**: Even 1 @_rawLayout+deinit in struct-body (within Buffer's enum body) crashes when sufficient cross-module SIL exists. Tested empirically in production.
2. **Class-ref interaction**: Ring.Inline can't be in Ring's struct body because Ring stores Storage.Heap (class ref). Slab/Arena CAN host Inline because their storage types aren't class-based.
3. **Same-file extension = extension-file**: Defining Ring.Inline via `extension Buffer.Ring { }` in Buffer.swift (same file) still crashes. The compiler treats ALL extensions identically regardless of file.
4. **`-disable-llvm-verify` + `-disable-sil-ownership-verifier`**: The combination suppresses both bugs. 391 tests pass.

### Production Context

These variants are standalone packages that attempt to reproduce the crash in isolation. Per [EXP-004a], the crash is context-sensitive and requires the full production dependency graph (Storage_Primitives + Cyclic_Index_Primitives + 5+ layers of @inlinable typed infrastructure). The variants document what patterns DON'T crash in isolation, narrowing the search space. The actual crash behavior was verified by modifying Buffer.swift in the production codebase.

## Build Protocol

```bash
rm -rf .build                                    # REQUIRED — incremental builds give false results
swift build -c release --target "V01-baseline"   # Per-variant build
swift build -c release 2>&1 | grep -c "Instruction does not dominate"  # Count errors
```

## Cross-References

- [release-mode-llvm-verifier-crash-diagnosis.md](../../Research/release-mode-llvm-verifier-crash-diagnosis.md) — Full diagnosis (Steps 1-8)
- [release-crash-resolution-handoff.md](../../Research/release-crash-resolution-handoff.md) — Resolution handoff
- [rawlayout-sil-ownership-crash](../rawlayout-sil-ownership-crash/) — Bug 2 (SIL ownership)
- [rawlayout-deinit-alternatives](../rawlayout-deinit-alternatives/) — Workaround exploration
