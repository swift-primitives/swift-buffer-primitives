# Linked CoW-Safe Overloads

<!--
---
version: 1.0.0
last_updated: 2026-02-12
status: DECISION
---
-->

## Context

Buffer.Ring and Buffer.Linear provide CoW-safe Copyable overloads of every mutating method. Each overload calls `_makeUnique()` before delegating to the core implementation. This allows consumers (Queue, Stack) to be thin semantic wrappers — they forward calls to buffer methods and get CoW automatically.

Buffer.Linked does not follow this pattern. It only exposes `ensureUnique()` as a standalone public method. Consumers (List.Linked) must duplicate every mutating method in a separate Copyable extension just to insert `ensureUnique()` before each call.

This was identified as an inconsistency in [buffer-variant-parity-analysis](buffer-variant-parity-analysis.md) (Section 12) and the correct pattern was recommended in [buffer-ring-consumer-api-boundary](buffer-ring-consumer-api-boundary.md) (Section A1, Outcome).

## Question

Should Buffer.Linked provide CoW-safe Copyable overloads of its mutating methods, consistent with Ring and Linear?

## Analysis

### Current State

| Buffer | `_makeUnique()` | CoW-safe overloads | Consumer duplicates methods? |
|--------|-----------------|-------------------|------------------------------|
| Linear | Yes (private)   | Yes — `append`, `removeFirst`, `removeLast`, `remove(at:)`, `replace(at:with:)`, `removeAll`, `reserveCapacity` | No — Stack forwards directly |
| Ring   | Yes (package)   | Yes — `pushBack`, `popFront`, `pushFront`, `popBack`, `removeAll`, `reserveCapacity`, `compact`, subscript `_modify` | No — Queue forwards directly |
| Linked | No              | No — only `ensureUnique()` standalone | Yes — List.Linked duplicates `prepend`, `append`, `popFirst`, `popLast`, `clear` |

### Option A: Add CoW-safe overloads to Buffer.Linked

Extract core logic into package-private `_insertFront`, `_insertBack`, `_removeFront`, `_removeBack`, `_removeAll`, `_ensureCapacity` methods. Add `_makeUnique()` and public Copyable overloads that call `_makeUnique()` then delegate.

**Advantages**:
- Consistent with Ring and Linear
- List.Linked Copyable extension reduces to genuinely different API (properties, conformances)
- CoW correctness guaranteed by buffer — consumers cannot forget
- Other future Linked consumers get CoW automatically

**Disadvantages**:
- Requires renaming existing public methods to package-private (source-breaking within the monorepo, but these are primitives — no external consumers yet)

### Option B: Keep status quo

**Advantages**:
- No changes to buffer-primitives
- Existing consumer pattern works

**Disadvantages**:
- Inconsistent with Ring/Linear
- Every consumer must duplicate every mutating method
- CoW correctness relies on consumer discipline
- Contradicts buffer-ring-consumer-api-boundary research recommendation

### Comparison

| Criterion | Option A | Option B |
|-----------|----------|----------|
| Consistency with Ring/Linear | Yes | No |
| Consumer code reduction | Significant | None |
| CoW correctness | Guaranteed by buffer | Consumer responsibility |
| Refactoring cost | Moderate (method renaming) | None |
| Prior research alignment | Fully aligned | Contradicts recommendations |

## Outcome

**Status**: DECISION

**Choice**: Option A — Add CoW-safe Copyable overloads to Buffer.Linked.

**Implementation**:

1. In `Buffer.Linked ~Copyable.swift`: rename `insertFront`, `insertBack`, `removeFront`, `removeBack`, `removeAll`, `ensureCapacity`, `reserveAdditionalCapacity` to package-private `_`-prefixed variants. Add thin public wrappers that delegate to them.

2. In `Buffer.Linked Copyable.swift`: add `_makeUnique()` (package-private). Add CoW-safe public overloads that call `_makeUnique()` then delegate to `_`-prefixed implementations.

3. In `List.Linked Copyable.swift`: remove duplicated mutating methods (`ensureUnique`, `prepend`, `append`, `popFirst`, `popLast`, `clear`). Keep only genuinely Copyable-specific API: `first`/`last` properties, `Sequence`, `Equatable`, `Hashable`.

**Rationale**: Buffer owns storage, buffer owns CoW. This is the principle established by Ring and Linear, documented in buffer-ring-consumer-api-boundary, and identified as a gap in buffer-variant-parity-analysis. Aligning Linked eliminates a class of consumer-side bugs and reduces code duplication.

## References

- [buffer-ring-consumer-api-boundary](buffer-ring-consumer-api-boundary.md) — Section A1, Outcome
- [buffer-variant-parity-analysis](buffer-variant-parity-analysis.md) — Section 12
- [linked-list-layered-architecture](/Users/coen/Developer/swift-primitives/swift-list-primitives/Research/linked-list-layered-architecture.md) — Storage/Buffer/DataStructure layering
