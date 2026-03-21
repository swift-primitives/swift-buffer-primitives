# Handoff: Consolidate @_rawLayout Experiment Corpus

## Your Mission

Consolidate ~14 scattered experiments across two packages into a coherent, deduplicated experiment corpus. The experiments all investigate the same family of compiler bugs: `@_rawLayout` + `~Copyable` + `deinit` under `-O` optimization. They were created incrementally over weeks of investigation and contain significant overlap.

## Context

Two compiler bugs block `swift build -c release` for swift-buffer-primitives:

1. **LLVM verifier crash**: `~Copyable` struct + `@_rawLayout` field + explicit `deinit` + `-O` → "Instruction does not dominate all uses!" Signal 6. Threshold depends on module and placement pattern.

2. **SIL ownership crash**: `@_rawLayout` types in serialized SIL → CopyPropagation pass → "Found ownership error?!" Signal 6. Pre-existing bug, affects downstream modules regardless of deinit presence.

Both require "sufficient cross-module serialized SIL" — standalone reproducers with local definitions don't crash. The experiments document the empirical investigation that discovered these constraints.

### Current workaround (in-progress)

All 4 Inline types keep their deinits. Package.swift suppresses both verifiers for release builds:
- `-Xfrontend -disable-llvm-verify` on Core target only
- `-Xfrontend -disable-sil-ownership-verifier` on all targets (release only)

391 tests pass. The workaround is package-local but downstream consumers MAY need the SIL flag if they trigger CopyPropagation on @_rawLayout paths.

## Authoritative Research Documents

Read these FIRST — they contain the synthesized findings:

1. `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Research/release-mode-llvm-verifier-crash-diagnosis.md` — Full diagnosis (v3.0.0, Steps 1-8)
2. `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Research/release-crash-resolution-handoff.md` — Resolution handoff with constraint triangle

These are the source of truth. The experiments below are the EMPIRICAL EVIDENCE that supports these documents.

## Experiments to Consolidate

### Group A: @_rawLayout + deinit crash (Bug 1)

These all investigate the same LLVM verifier crash from different angles:

| Experiment | Package | Variants | What it tests |
|-----------|---------|----------|---------------|
| `rawlayout-release-verifier-crash/` | buffer-primitives | 3 modules | Original crash investigation — threshold, patterns |
| `rawlayout-deinit-investigation/` | storage-primitives | 1 module + summary | Initial deinit investigation |
| `rawlayout-deinit-incremental/` | storage-primitives | 17 modules + FINDINGS.md | Most mature — systematic incremental testing |
| `rawlayout-deinit-crossmodule/` | storage-primitives | 2 modules + tests | Cross-module @_rawLayout + deinit |
| `rawlayout-wrapper-validation/` | storage-primitives | 1 module | Wrapper pattern as workaround |
| `rawlayout-noncopyable-elements/` | storage-primitives | 1 module | ~Copyable elements in @_rawLayout |
| `cross-module-type-declaration/` | buffer-primitives | 3 modules | Cross-module type declaration patterns |

**Overlap**: `rawlayout-deinit-investigation` → `rawlayout-deinit-incremental` → `rawlayout-deinit-crossmodule` is a clear progression. The buffer-primitives `rawlayout-release-verifier-crash` covers similar ground from the buffer perspective. `rawlayout-wrapper-validation` and `rawlayout-noncopyable-elements` are single-variant explorations that could be variants within the main experiment.

### Group B: Deinit lifecycle and alternatives (Bug 1 workarounds)

| Experiment | Package | Variants | What it tests |
|-----------|---------|----------|---------------|
| `slab-deinit-workaround/` | buffer-primitives | 1 module | Slab-specific deinit workaround |
| `deinit-guard-idempotence/` | storage-primitives | 1 module | Idempotent deinit guard pattern |
| `discard-self-availability/` | storage-primitives | 1 module | `discard self` as deinit alternative |
| `escapable-deinit-lifetime/` | storage-primitives | 2 modules | @_unsafeNonescapableResult in deinit |

**Overlap**: These all explore alternatives to the standard deinit pattern. The escapable-deinit-lifetime experiment is referenced by the Property.View accessor workaround in production code.

### Group C: SIL / CopyPropagation crashes (Bug 2)

| Experiment | Package | Variants | What it tests |
|-----------|---------|----------|---------------|
| `copy-propagation-noncopyable-enum/` | buffer-primitives | 2 modules | CopyPropagation crash with ~Copyable enum |
| `noncopyable-enum-modify/` | buffer-primitives | 1 module | ~Copyable enum _modify path |
| `small-enum-modify-recovery/` | buffer-primitives | 1 module | Small enum modify recovery |

**Overlap**: These may all be manifestations of the same SIL ownership bug. The enum modify experiments could be variants of the copy-propagation experiment.

## Consolidation Plan

### Target structure

Consolidate into 3 experiments (one per bug + one for workarounds):

```
swift-buffer-primitives/Experiments/
├── rawlayout-llvm-verifier-crash/       ← Group A (Bug 1)
│   ├── EXPERIMENT.md                     ← Manifest per /experiment-process
│   ├── Package.swift
│   ├── Sources/
│   │   ├── V01-baseline/                ← Minimal trigger
│   │   ├── V02-struct-body-threshold/   ← ≤2 threshold
│   │   ├── V03-extension-file/          ← Extension-file crashes with 1
│   │   ├── V04-cross-module/            ← Cross-module extension crashes
│   │   ├── V05-class-ref-interaction/   ← Storage.Heap + @_rawLayout
│   │   ├── V06-wrapper-patterns/        ← Wrapper/indirection attempts
│   │   ├── V07-noncopyable-elements/    ← ~Copyable element specifics
│   │   └── V08-storage-inline-deinit/   ← Storage.Inline deinit attempt
│   └── Tests/
│
├── rawlayout-sil-ownership-crash/       ← Group C (Bug 2)
│   ├── EXPERIMENT.md
│   ├── Package.swift
│   ├── Sources/
│   │   ├── V01-copy-propagation/        ← CopyPropagation trigger
│   │   ├── V02-enum-modify/             ← ~Copyable enum _modify
│   │   └── V03-downstream-infection/    ← Cross-module SIL crash
│   └── Tests/
│
├── rawlayout-deinit-alternatives/       ← Group B (workaround exploration)
│   ├── EXPERIMENT.md
│   ├── Package.swift
│   ├── Sources/
│   │   ├── V01-discard-self/
│   │   ├── V02-guard-idempotence/
│   │   ├── V03-escapable-lifetime/      ← Property.View accessor pattern
│   │   └── V04-slab-bitmap-cleanup/
│   └── Tests/
```

### What to do with storage-primitives experiments

The storage-primitives experiments (`rawlayout-deinit-*`, `escapable-deinit-lifetime`, etc.) contain findings that are relevant to buffer-primitives. Two options:

**Option A** (recommended): Absorb into the buffer-primitives consolidated experiments above. The storage-primitives experiments were investigating the SAME bugs from the storage perspective. Their findings are captured in the diagnosis document. Archive the originals in storage-primitives with a redirect note.

**Option B**: Keep storage-primitives experiments in-place, add cross-references. Less disruptive but perpetuates duplication.

### For each consolidated experiment

Use `/experiment-process` to create proper EXPERIMENT.md manifests. Each variant should document:

1. **What it tests** (one sentence)
2. **Expected result** (crash / pass)
3. **Actual result** (with exact error and build command)
4. **Which diagnosis finding it supports** (e.g., "confirms Step 6: struct-body ≤2 threshold")

### Preservation rules

- Do NOT delete original experiments until consolidation is verified
- Preserve any FINDINGS.md or INVESTIGATION-SUMMARY.md content — merge into EXPERIMENT.md
- Preserve working Package.swift configurations — they ARE the experiment
- If an experiment has Tests/, preserve them as verification

## Research documents to update

After consolidation, update these to reference the new experiment paths:

- `release-mode-llvm-verifier-crash-diagnosis.md` — Cross-References section
- `release-crash-resolution-handoff.md` — Experiment Location section
- `small-buffer-enum-compiler-workarounds.md` — if it references old experiments

Also update:
- `swift-storage-primitives/Research/escapable-deinit-lifetime.md` — if it references the old experiment
- `swift-storage-primitives/Research/inline-deinit-ownership.md` — same

## New findings to incorporate

This session discovered findings NOT yet in any experiment:

1. **Storage Primitives Core has threshold 0**: Even 1 @_rawLayout+deinit (struct-body in Buffer's enum body) crashes. Tested empirically.
2. **Class-ref interaction**: Ring.Inline can't be in Ring's struct body because Ring stores Storage.Heap (class ref). Slab/Arena CAN host Inline because their storage types aren't class-based.
3. **Same-file extension = extension-file**: Defining Ring.Inline via `extension Buffer.Ring { }` in Buffer.swift (same file as Buffer) still crashes. The compiler treats ALL extensions identically regardless of file.
4. **SIL ownership crash is pre-existing**: Happens WITH all 4 deinits intact. Not caused by removing deinits. Was masked by the LLVM crash preventing Core from building.
5. **Adding deinit to Small types causes 85+ errors**: "cannot partially consume 'self' when it has a deinitializer" — breaks all consuming methods.
6. **`-disable-llvm-verify` + `-disable-sil-ownership-verifier`**: The combination suppresses both bugs. 391 tests pass.

These should become variants in the consolidated experiments.

## Success criteria

1. ~14 experiments → 3 consolidated experiments
2. Every finding in the diagnosis document has a corresponding experiment variant
3. New session findings (items 1-6 above) are captured as variants
4. No experiment content is lost (archived or merged)
5. EXPERIMENT.md manifests per `/experiment-process` skill
6. Cross-references updated in research documents
