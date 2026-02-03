# Dependency Reuse Audit for Theoretical Buffer-Primitives Design

<!--
---
version: 1.0.0
last_updated: 2026-02-03
status: DECISION
---
-->

## Context

The converged buffer-primitives design (see `theoretical-buffer-primitives-design.md`) specifies a Tier 13 package with 6 declared dependencies. The ecosystem's **maximum dependency reuse principle** requires that buffer-primitives MUST use lower-tier primitives rather than reimplementing equivalent logic locally.

This audit systematically identifies every operation in the buffer design and maps it to the dependency that provides it, flagging any operation that might be inadvertently reimplemented.

**Trigger**: Post-convergence action item from collaborative discussion (Round 2, A3).

## Question

Are there any operations in the buffer-primitives design that would duplicate logic already available in its declared dependencies?

## Analysis

### Dependency Inventory

| Package | Tier | Key Types/Operations Used |
|---------|------|---------------------------|
| `swift-storage-primitives` | 12 | `Storage.Heap`, `Storage.Inline`, `Storage.Initialization`, `Index<Storage>`, initialize/move/deinitialize/withSpan, copy/move-range |
| `swift-bit-vector-primitives` | 13 | `Bit.Vector`, `Bit.Vector.Static`, subscript, popcount, set/clear/ones.forEach |
| `swift-sequence-primitives` | 7 | `Sequence.Protocol`, `Sequence.Borrowing.Protocol`, `Sequence.Consume.Protocol`, `Sequence.Drain.Protocol`, `Sequence.Clearable`, Property.View tags |
| `swift-cyclic-index-primitives` | 9 | `Index<Tag>.Cyclic<N>`, `Modular.successor`, `Modular.predecessor`, `Modular.advanced`, `Modular.physical` |
| `swift-cyclic-primitives` | 8 | `Cyclic.Group.Static<N>`, `Cyclic.Group.Modulus`, modular add/subtract/successor/predecessor/inverse/advanced |
| `swift-index-primitives` | 6 | `Index<T>`, `Index<T>.Count`, `Index<T>.Offset`, affine arithmetic (+/-), modulo (%), pointer subscripts, span construction |
| `swift-memory-primitives` | 10 | `Memory.Alignment`, `Memory.Contiguous.Protocol`, `Memory.Allocator.Protocol` |

### Operation-by-Operation Audit

#### Ring Buffer — Modular Index Arithmetic

| Operation | Naive Implementation | Correct Dependency |
|-----------|---------------------|-------------------|
| `(head + count) mod capacity` (tail computation) | `Index<Storage>((head.position.rawValue + count.rawValue) % capacity.rawValue)` | `Modular.advanced(head, by: Index<Storage>.Offset(fromZero: count), capacity: capacity)` OR `Index<Storage>(head.position % capacity)` |
| `(head + 1) mod capacity` (pop front) | Manual modulo | `Modular.successor(of: head, capacity: capacity)` |
| `(head - 1) mod capacity` (push front) | Manual modulo with underflow guard | `Modular.predecessor(of: head, capacity: capacity)` |
| Logical-to-physical index mapping | `(head + logicalIndex) mod capacity` | `Modular.physical(forLogical:head:capacity:)` — purpose-built |
| Compile-time modular arithmetic (Bounded) | Manual `% N` | `Index<Storage>.Cyclic<N>` arithmetic (`+`, `-` operators) |

**Finding**: `cyclic-index-primitives` provides `Modular.physical(forLogical:head:capacity:)` which is exactly the logical→physical slot mapping ring buffers need. This MUST be used instead of writing `(head + i) % capacity` locally.

**Finding**: For `Ring.Bounded`, `Index<Storage>.Cyclic<capacity>` provides compile-time modular arithmetic. The `Header.Cyclic<capacity>` type should store `head` as `Index<Storage>.Cyclic<capacity>` to get free modular operations.

#### Ring Buffer — Initialization State

| Operation | Risk | Correct Approach |
|-----------|------|-----------------|
| Compute `Storage.Initialization` from ring state | Reimplement range construction | Use `Storage.Initialization.one(Range(start:count:))` and `.two(first:second:)` directly — these are already provided by storage-primitives' Range extension `init(start:count:)` |
| Transition from `.one` to `.two` on wrap | Ad-hoc range splitting | Compute from `head`, `count`, `capacity` — no existing primitive covers this specific transition (buffer-local logic is correct here) |

**Finding**: `Range<Index<Storage>>.init(start:count:)` is provided by storage-primitives. Use it for constructing initialization ranges rather than writing `start..<(start + count)` manually.

#### Linear Buffer — Index Arithmetic

| Operation | Risk | Correct Approach |
|-----------|------|-----------------|
| Append at position `count` | Convert count to index | `Index<Storage>` from count — use affine conversion |
| Element shift on consume-front | Manual loop | `Storage.Heap.move(range:to:)` — storage-primitives provides range move |

**Finding**: `Storage.Heap.move(range:to:)` can handle the element shift in `consumeFront`. The linear buffer does NOT need a custom element-by-element shift loop — the storage range-move operation does this.

#### Slab Buffer — Bitmap Operations

| Operation | Risk | Correct Approach |
|-----------|------|-----------------|
| Check slot occupied | `bitmap[i]` | `Bit.Vector` subscript — already the plan |
| Set slot occupied | `bitmap[i] = true` | `Bit.Vector` subscript set — already the plan |
| Clear slot | `bitmap[i] = false` | `Bit.Vector` subscript set — already the plan |
| Count occupied | Manual bit count | `Bit.Vector.popcount` (from `ones.count.all`) — already the plan |
| Iterate occupied slots | Manual word iteration | `Bit.Vector.ones.forEach` — already the plan |
| Find first vacant | Manual word scan | Requires `Bit.Vector.zeros.first` or equivalent — verify availability |

**Finding**: Need to verify that `Bit.Vector` provides a "first zero" / "first vacant" scan. If `ones.forEach` exists but not a `zeros` equivalent, `firstVacant` may need to iterate words manually using bitwise complement + trailing zeros. This would be acceptable local logic since it operates at the word level.

#### Slab Buffer — Index Bridge

| Operation | Risk | Correct Approach |
|-----------|------|-----------------|
| `Index<Storage>` ↔ `Bit.Index` conversion | Manual `rawValue` extraction | Use `Index.retag()` from identity-primitives (zero-cost phantom-type conversion via Tagged.retag) |

**Finding**: `Tagged.retag(to:)` is the zero-cost cross-domain index conversion provided by identity-primitives (re-exported through index-primitives). The `Bit.Index ↔ Index<Storage>` bridge should use `.retag(Storage.self)` / `.retag(Bit.self)` — NOT manual rawValue extraction and reconstruction.

#### Growth Policy — Capacity Computation

| Operation | Risk | Correct Approach |
|-----------|------|-----------------|
| Double capacity | `Cardinal(capacity.rawValue * 2)` | Local logic — no dependency provides growth policy (this is buffer-specific) |
| Page-align capacity | Manual alignment rounding | `Memory.Alignment.alignUp()` from memory-primitives |

**Finding**: `Memory.Alignment.alignUp()` MUST be used for page-aligned growth, not manual `(capacity + pageSize - 1) / pageSize * pageSize`.

#### Sequence Protocol Conformances

| Operation | Risk | Correct Approach |
|-----------|------|-----------------|
| `makeIterator()` | Custom iterator type | Conform to `Sequence.Protocol` from sequence-primitives |
| Span-based iteration | Custom span iteration | Conform to `Sequence.Borrowing.Protocol` |
| Consuming drain | Custom drain loop | Conform to `Sequence.Consume.Protocol` or `Sequence.Drain.Protocol` |
| `removeAll()` | Custom clear logic | Conform to `Sequence.Clearable` |
| Property.View integration | Custom accessors | Use tags from sequence-primitives (`Sequence.ForEach`, `Sequence.Count`, `Sequence.Drain`, etc.) |

**Finding**: All iteration is covered by sequence-primitives protocols and Property.View tags. No custom iteration infrastructure needed.

#### Pointer Arithmetic

| Operation | Risk | Correct Approach |
|-----------|------|-----------------|
| Advance pointer by index | `pointer + Int(index.rawValue)` | `UnsafePointer<T>[idx: Index<T>]` subscript from index-primitives |
| Pointer distance | `ptr2 - ptr1` | `UnsafeMutablePointer<T> - UnsafeMutablePointer<T> → Index<T>.Offset` from index-primitives |

**Finding**: index-primitives provides typed pointer subscripts and arithmetic. These MUST be used instead of raw integer pointer offsets.

#### Count/Cardinal Operations

| Operation | Risk | Correct Approach |
|-----------|------|-----------------|
| Count subtraction | `count - 1` | `Cardinal.subtract.exact()` (throwing) or `.subtract.saturating()` from cardinal-primitives (re-exported through index-primitives) |
| Count comparison | `count > 0` | Direct — `Cardinal` is `Comparable` |
| Count to Int | `Int(count.rawValue)` | Direct — but prefer staying in Cardinal domain |

**Finding**: `Cardinal` does NOT have a `-` operator by design. Use `.subtract.exact()` (throws on underflow) or `.subtract.saturating()` (clamps to zero). Buffer-primitives MUST NOT work around this by extracting rawValue.

### Summary Matrix

| Category | Operations | Dependency | Status |
|----------|-----------|------------|--------|
| Modular arithmetic (dynamic) | successor, predecessor, advanced, physical | `cyclic-index-primitives` | MUST USE |
| Modular arithmetic (static) | `+`, `-` on cyclic index | `cyclic-primitives` via `Index.Cyclic<N>` | MUST USE |
| Index bridge (Slab) | Bit.Index ↔ Index\<Storage\> | `identity-primitives` via `.retag()` | MUST USE |
| Range construction | `Range(start:count:)` | `storage-primitives` range extension | MUST USE |
| Range move/copy | `move(range:to:)`, `copy(range:to:)` | `storage-primitives` | MUST USE |
| Pointer access | subscript, arithmetic | `index-primitives` | MUST USE |
| Page alignment | `alignUp()` | `memory-primitives` | MUST USE |
| Count arithmetic | subtract, compare | `cardinal-primitives` (via index-primitives) | MUST USE |
| Iteration protocols | Sequence, Borrowing, Consume, Drain, Clearable | `sequence-primitives` | MUST USE |
| Property.View tags | forEach, count, drain, etc. | `sequence-primitives` | MUST USE |
| Growth policy | doubling, factor, exact | None — buffer-local | CORRECT (local) |
| Initialization transitions | `.empty` ↔ `.one` ↔ `.two` | None — buffer-local from header state | CORRECT (local) |
| Slab firstVacant | word-level zero scan | None — buffer-local (verify Bit.Vector) | CORRECT (local, pending verification) |

## Outcome

**Status**: DECISION

**No missing delegation found** — the design correctly identifies all dependencies and the converged plan calls for their use. However, the audit identifies **5 specific implementation hazards** where a developer might inadvertently reimplement existing primitives:

1. **Ring modular arithmetic**: Use `Modular.successor`/`predecessor`/`physical`, NOT manual `%`
2. **Slab index bridge**: Use `Tagged.retag()`, NOT rawValue extraction
3. **Linear element shift**: Use `Storage.Heap.move(range:to:)`, NOT element-by-element loop
4. **Count subtraction**: Use `Cardinal.subtract.exact()`, NOT `rawValue - 1`
5. **Page-aligned growth**: Use `Memory.Alignment.alignUp()`, NOT manual rounding

These 5 points should be documented as implementation constraints in the buffer-primitives codebase (e.g., in a `CONTRIBUTING.md` or code comments at the usage sites).

**Action**: Mark `[x]` on the dependency reuse audit action item in the converged plan.

## References

- `theoretical-buffer-primitives-design.md` — converged design
- `swift-cyclic-index-primitives` — `Modular` namespace, `Index.Cyclic<N>`
- `swift-index-primitives` — `Index<T>`, `Tagged.retag()`, pointer subscripts
- `swift-storage-primitives` — `Storage.Initialization`, range operations
- `swift-memory-primitives` — `Memory.Alignment.alignUp()`
- `swift-sequence-primitives` — iteration protocols, Property.View tags
- `swift-cardinal-primitives` — `Cardinal.subtract.exact()`
