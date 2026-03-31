# Buffer Primitives Insights

<!--
---
title: Buffer Primitives Insights
version: 1.0.0
last_updated: 2026-02-13
applies_to: [swift-buffer-primitives]
normative: false
---
-->

Design decisions, implementation patterns, and lessons learned specific to this package.

## Overview

This document captures insights that emerged during development of swift-buffer-primitives.
These are not API requirements — they are recorded decisions and patterns that inform
future work on this package.

**Document type**: Non-normative (recorded decisions, not requirements).

**Consolidation source**: Reflection entries tagged with `[package: swift-buffer-primitives]`.

---

## Unbounded Bit.Index Audit Needed on Slab Variants

**Date**: 2026-02-13

**Context**: During stack-buffer remediation, `Buffer.Slab.Inline.isOccupied(at:)` was found to accept unbounded `Bit.Index` while all other Slab APIs (`insert`, `remove`, `peek`, `firstVacant`) used `Bit.Index.Bounded<wordCount>`. The fix was subtractive: remove the unbounded variant, make `Bit.Index.Bounded<wordCount>` the sole public API.

A systematic audit of remaining `Buffer.Slab.Inline` and `Buffer.Slab.Bounded` public APIs may reveal additional unbounded `Bit.Index` parameters that should be `Bit.Index.Bounded<wordCount>`. The `Buffer.Slab.Small` variant narrows at its delegation boundary and may also have inconsistencies.

**Applies to**: `Buffer.Slab.Inline`, `Buffer.Slab.Bounded`, `Buffer.Slab.Small`

---

## Experiment Consolidation Packaging Defects

**Date**: 2026-03-21

**Context**: During consolidation of 14 @_rawLayout experiments into 3 coherent groups, 4 packaging defects were identified in the consolidated experiment variants.

Defects identified: V04 missing public init, V08 Sendable conformance, V01 visibility issue, V03 attribute issue. These are in the consolidated experiment packages under `Experiments/`, not in production code.

**Applies to**: `Experiments/rawlayout-llvm-verifier-crash/`, `Experiments/rawlayout-sil-ownership-crash/`, `Experiments/rawlayout-deinit-alternatives/`

---

## Ideal Architecture After Compiler Fix

**Date**: 2026-03-22

**Context**: A 21-line compiler fix for swiftlang/swift#86652 (IRGen element-wise vs VWT destruction for public ~Copyable types with @_rawLayout) was written, validated against 2,284 compiler tests, and confirmed to eliminate the LLVM verifier crash.

Once the compiler fix lands upstream, the ideal architecture becomes possible:
1. Add `deinit` to `Storage.Inline` (combined @_rawLayout layout)
2. Remove all 22 `_deinitWorkaround: AnyObject?` sites across 10 packages
3. Remove buffer-layer deinits that exist solely to compensate for Storage.Inline lacking deinit

The `rawlayout-access-level-trigger` experiment is the canary — when it passes on the upstream toolchain, the migration can begin.

**Applies to**: `Storage.Inline`, `Buffer.Ring.Inline`, `Buffer.Linear.Inline`, `Buffer.Slab.Inline`, all data structure types with `_deinitWorkaround`

---

## DeinitDevirtualizer ICE on Buffer.Unbounded (2026-03-31)

**Date**: 2026-03-31

**Context**: Building the Async Channel module on Swift 6.4-dev hits a `DeinitDevirtualizer` ICE on `Buffer.Unbounded.swift:40` (pass #45472, SIL assertion on substitutions vs generic signature). This is a separate optimizer bug from the CopyPropagation issue (#85743). It blocks full superrepo builds on 6.4-dev, which complicates verification of compiler fixes. Needs its own investigation handoff per the issue-investigation skill.

**Applies to**: Buffer.Unbounded, Async Channel module on 6.4-dev
