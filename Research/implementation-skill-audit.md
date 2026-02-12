# Implementation Skill Audit

<!--
---
version: 1.0.0
last_updated: 2026-02-12
status: RECOMMENDATION
---
-->

## Context

Buffer-primitives reached functional completeness across six buffer disciplines (Linear, Ring, Slab, Arena, Linked, Slots) with full `~Copyable` support. A 100% strictness audit against the **implementation** skill was conducted to verify convention compliance before stabilization.

The audit revealed that the majority of violations stem from **not importing existing Standard Library Integration modules**, not from missing infrastructure. This document records the findings and catalogs what already exists.

## Question

Which violations in buffer-primitives require new infrastructure, and which are resolved by importing existing boundary overloads?

## Analysis

### Audit Scope

97 source files across 8 modules were audited against every `[IMPL-*]` and `[PATTERN-*]` rule in the implementation skill.

### Violation Summary

| Module | Violations | MUST | SHOULD |
|--------|-----------|------|--------|
| Buffer Primitives Core | 0 | 0 | 0 |
| Buffer Slots Primitives | 0 | 0 | 0 |
| Buffer Linear Primitives | 4+ | 3 | 1+ |
| Buffer Ring Primitives | 6+ | 3 | 3+ |
| Buffer Slab Primitives | 14 | 8 | 6 |
| Buffer Arena Primitives | 24 | 18 | 6 |
| Buffer Linked Primitives | 24 | 18 | 6 |
| **Total** | **72+** | **50+** | **22+** |

Re-verification with exact line counts found additional `Int(bitPattern:)` sites in Span files not caught in the initial sweep, increasing the Linear and Ring counts.

### Three Systemic Patterns

| Pattern | Sites | Rule |
|---------|-------|------|
| `Int(bitPattern:)` at call sites | ~64 | [IMPL-010] |
| `.rawValue.rawValue` chains (Arena) | ~13 | [IMPL-002], [PATTERN-017] |
| Compound public identifiers (Linked) | ~12 | [API-NAME-002] |

### Existing Infrastructure Discovery

The critical finding: most `Int(bitPattern:)` violations are **import gaps**, not infrastructure gaps.

#### Cardinal Primitives Standard Library Integration

Already provides (in `swift-cardinal-primitives`):

| Overload | File | Sites It Resolves |
|----------|------|-------------------|
| `Span.init(_unsafeStart:, count: Cardinal.Protocol)` | `Span+Cardinal.swift` | ~14 Span constructors |
| `UnsafeBufferPointer.init(start:, count: Cardinal.Protocol)` | `UnsafeBufferPointer+Cardinal.swift` | ~14 buffer pointer constructors |
| `UnsafeMutableBufferPointer.init(start:, count: Cardinal.Protocol)` | `UnsafeMutableBufferPointer+Cardinal.swift` | Mutable buffer pointer sites |
| `UnsafeMutableBufferPointer.allocate(capacity: Cardinal.Protocol)` | `UnsafeMutableBufferPointer+Cardinal.swift` | Allocation sites |
| `Int.init(bitPattern: Cardinal)` | `Int+Cardinal.swift` | Growth arithmetic, comparisons |
| `Int.init(clamping: Cardinal)` | `Int+Cardinal.swift` | `underestimatedCount` properties |
| `ContiguousArray.init(repeating:, count: Cardinal.Protocol)` | `ContiguousArray+Cardinal.swift` | Array initialization |
| `MutableSpan.init(_unsafeStart:, count: Cardinal.Protocol)` | `MutableSpan+Cardinal.swift` | Mutable span constructors |

Buffer-primitives does **not** currently import `Cardinal_Primitives_Standard_Library_Integration`.

#### Ordinal Primitives Standard Library Integration

Already provides (in `swift-ordinal-primitives`):

| Overload | File | Sites It Resolves |
|----------|------|-------------------|
| `UnsafePointer[O: Ordinal.Protocol]` subscript | `UnsafePointer+Ordinal.swift` | ~12 pointer element access sites |
| `UnsafeMutablePointer[O: Ordinal.Protocol]` subscript | `UnsafeMutablePointer+Ordinal.swift` | Mutable pointer access |
| `Int.init(bitPattern: Ordinal)` | `Int+Ordinal.swift` | Ordinal-to-Int boundary sites |

Buffer-primitives does **not** currently import `Ordinal_Primitives_Standard_Library_Integration`.

#### Memory Primitives Standard Library Integration

Already provides (in `swift-memory-primitives`):

| Overload | File | Sites It Resolves |
|----------|------|-------------------|
| `memory.move.initialize(as:, from:, count: Index<T>.Count)` | `Memory+UnsafeMutableRawPointer.Memory.Move.swift` | Raw pointer move-initialize |
| `memory.initialize(as:, from:, count: Index<T>.Count)` | `Memory+UnsafeMutableRawPointer.Memory.swift` | Raw pointer initialize |

Note: these are on `UnsafeMutableRawPointer`, not `UnsafeMutablePointer<T>`. The typed pointer `moveInitialize(from:, count:)` overload is still missing.

#### Affine Primitives — Ratio for Capacity Doubling

`Affine.Discrete.Ratio<From, To>` (in `swift-affine-primitives`) already supports typed scaling:

```swift
// Existing operator in Tagged+Affine.swift:
Tagged<From, Cardinal> * Affine.Discrete.Ratio<From, To> → Tagged<To, Cardinal>
```

Capacity doubling in `_grow()` methods should use:
```swift
// Old (mechanism):
Cardinal($0.rawValue &<< 1)

// New (intent):
capacity * Affine.Discrete.Ratio<Element, Element>(2)
```

#### Identity Primitives — `.retag()` for Bit.Index

`Tagged.retag(_:)` (in `swift-identity-primitives`) provides zero-cost phantom type conversion:

```swift
// Old (triple chain):
Bit.Index(Ordinal(UInt(i)))

// New (zero-cost retag):
slot.retag(Bit.self)
```

Valid when `Index<Element>` and `Bit.Index` share the same ordinal value (slot N = bit N), which is the case in Slab bitmap operations.

### Classification of All Violations

#### Pure Import Gaps (~45 sites)

Resolved by adding `Cardinal_Primitives_Standard_Library_Integration` and `Ordinal_Primitives_Standard_Library_Integration` as dependencies of buffer-primitives:

- All Span constructor `Int(bitPattern:)` sites
- All UnsafeBufferPointer constructor sites
- All `underestimatedCount` properties (use `Int(clamping:)`)
- Growth arithmetic `Int(bitPattern:)` sites
- Pointer element access via subscript

#### Use Existing Infrastructure (~8 sites)

No new code, just change call-site expressions:

- Capacity doubling: use `Affine.Discrete.Ratio` (3 sites: Linear, Ring, Linked)
- Bit.Index construction: use `.retag(Bit.self)` (2 sites in Slab)
- Pointer element access: use ordinal subscript (3 sites)

#### Genuine Infrastructure Gaps (~3 sites)

New boundary overloads needed:

| Gap | What | Where to Add | Sites |
|-----|------|-------------|-------|
| `UnsafeMutablePointer<T>.moveInitialize(from:, count: Cardinal.Protocol)` | Typed pointer move-initialize | Cardinal Primitives Standard Library Integration | ~3 |

#### Design Decision Required (~13 sites)

Arena `UInt32(slot.rawValue.rawValue)` pattern:

- `Buffer.Arena.Meta` uses `UInt32` internally for memory efficiency (8-byte Position handles)
- `UnsafeMutablePointer<Meta>` subscript requires `Int` (stdlib constraint)
- The `UInt32` intermediate documents the `UInt32.max` capacity bound
- Options: (a) add `UInt32.init(bitPattern: Index<T>)` boundary, (b) change Meta subscript to accept `Index<Element>`, (c) accept as same-package implementation detail with WORKAROUND comment

#### Naming Violations (~12 sites)

Compound public identifiers in Buffer.Linked (`insertFront`, `insertBack`, `removeFront`, `removeBack`):

- Requires Property.View nested accessors: `insert.front()`, `remove.back()`
- Affects 3 files: `Buffer.Linked ~Copyable.swift`, `Buffer.Linked Copyable.swift`, `Buffer.Linked.Inline ~Copyable.swift`
- Static methods (`Buffer.Linked+Pool ~Copyable.swift`) may keep compound names per [IMPL-024]

## Outcome

**Status**: RECOMMENDATION

### Action Items (by priority)

1. **Import existing integration modules** (highest impact, lowest effort)
   - Add `Cardinal_Primitives_Standard_Library_Integration` dependency
   - Add `Ordinal_Primitives_Standard_Library_Integration` dependency
   - Update call sites to use typed overloads

2. **Use existing infrastructure at call sites**
   - Replace `.rawValue &<< 1` with `Affine.Discrete.Ratio` multiplication
   - Replace `Bit.Index(Ordinal(UInt(i)))` with `.retag(Bit.self)`

3. **Add missing typed pointer overload**
   - `UnsafeMutablePointer<T>.moveInitialize(from:, count: Cardinal.Protocol)` in cardinal integration

4. **Resolve Arena UInt32 boundary** (design decision needed)
   - Investigate whether `UInt32.init(bitPattern: Index<T>)` is the right boundary

5. **Add Property.View nested accessors for Linked** (naming compliance)
   - `insert.front()`, `insert.back()`, `remove.front()`, `remove.back()`

### Dependency Order

Items 1-2 are independent. Item 3 adds one overload to cardinal-primitives. Item 4 requires a design decision (possibly separate research). Item 5 is independent.

## References

- **implementation** skill — all `[IMPL-*]` and `[PATTERN-*]` rules
- **conversions** skill — `[CONV-001]` rawValue access location
- **naming** skill — `[API-NAME-002]` no compound identifiers
- Cardinal Primitives Standard Library Integration: `/Users/coen/Developer/swift-primitives/swift-cardinal-primitives/Sources/Cardinal Primitives Standard Library Integration/`
- Ordinal Primitives Standard Library Integration: `/Users/coen/Developer/swift-primitives/swift-ordinal-primitives/Sources/Ordinal Primitives Standard Library Integration/`
- Memory Primitives Standard Library Integration: `/Users/coen/Developer/swift-primitives/swift-memory-primitives/Sources/Memory Primitives Standard Library Integration/`
- Affine Primitives Ratio: `/Users/coen/Developer/swift-primitives/swift-affine-primitives/Sources/Affine Primitives Core/Affine.Discrete.Ratio.swift`
- Identity Primitives retag: `/Users/coen/Developer/swift-primitives/swift-identity-primitives/Sources/Identity Primitives/Tagged.swift`
