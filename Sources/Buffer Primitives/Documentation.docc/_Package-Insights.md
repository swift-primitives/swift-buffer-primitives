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
