# @_rawLayout SIL Ownership Crash and Enum _modify Investigation

<!--
---
status: CONFIRMED (compiler bug + language limitation)
date: 2026-03-21
toolchain: Swift 6.2.4 (Xcode, arm64 macOS 26)
consolidation_of:
  - swift-buffer-primitives/Experiments/copy-propagation-noncopyable-enum/
  - swift-buffer-primitives/Experiments/noncopyable-enum-modify/
  - swift-buffer-primitives/Experiments/small-enum-modify-recovery/
supports: release-mode-llvm-verifier-crash-diagnosis.md, small-buffer-enum-compiler-workarounds.md
---
-->

## Question

Under what conditions do @_rawLayout types trigger SIL ownership crashes, and what are the limits of `_modify` on ~Copyable enum payloads?

## Summary

Two related issues in the SIL optimization pipeline:

**Bug 2: SIL Ownership Crash** — `@_rawLayout` types in serialized SIL trigger CopyPropagation pass → "Found ownership error?!" signal 6. Pre-existing bug, affects downstream modules regardless of deinit presence. Was masked by the LLVM verifier crash (Bug 1) preventing Core from building.

**Language Limitation: Enum _modify** — Swift cannot yield mutable references into ~Copyable enum payloads. Optional gets special compiler support via `unchecked_take_enum_data_addr` (single-payload optimization). Multi-payload enums lack this, making zero-cost `_modify` into enum cases impossible. This affects `Buffer.*.Small._Representation` which uses `case inline(Inline) | case heap(Heap)`.

### Workaround

`-Xfrontend -disable-sil-ownership-verifier` on all targets (release only) suppresses Bug 2. For enum _modify: heap case recoverable via let-binding pointer bypass; inline case must spill to heap first.

## Variants

| Variant | Tests | Expected | Actual | Supports |
|---------|-------|----------|--------|----------|
| V01-copy-propagation | CopyPropagation crash with ~Copyable enum switch | Crash in production | REFUTED in isolation | Context-sensitive per [EXP-004a] |
| V02-enum-modify | _modify into ~Copyable enum payloads (8 variants) | Cannot yield &payload | CONFIRMED — language limitation | Compiler source analysis |
| V03-enum-modify-recovery | Recovery strategies: heap pointer bypass, inline spill | Heap recoverable | CONFIRMED — heap _modify works | DiagnoseStaticExclusivity fix |

### New Session Findings (2026-03-20)

1. **SIL ownership crash is pre-existing**: Happens WITH all 4 Inline deinits intact. Not caused by removing deinits. Was masked by the LLVM verifier crash preventing Core from building.
2. **Adding deinit to Small types causes 85+ errors**: "cannot partially consume 'self' when it has a deinitializer" — breaks all consuming methods in the Small buffer types.

## Build Protocol

```bash
rm -rf .build
swift build -c release --target "V01-copy-propagation"
swift build --target "V02-enum-modify"      # debug only (tests compile behavior)
swift build --target "V03-enum-modify-recovery"
swift run V03-enum-modify-recovery          # runtime verification
```

## Cross-References

- [release-mode-llvm-verifier-crash-diagnosis.md](../../Research/release-mode-llvm-verifier-crash-diagnosis.md)
- [small-buffer-enum-compiler-workarounds.md](../../Research/small-buffer-enum-compiler-workarounds.md) — Bug 2 and 3 documented here
- [rawlayout-llvm-verifier-crash](../rawlayout-llvm-verifier-crash/) — Bug 1 (LLVM verifier)
- [rawlayout-deinit-alternatives](../rawlayout-deinit-alternatives/) — Workaround exploration
