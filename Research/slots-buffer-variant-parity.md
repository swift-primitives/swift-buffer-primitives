# Slots Buffer Variant Parity

<!--
---
version: 1.0.0
last_updated: 2026-02-12
status: RECOMMENDATION
research_tier: 1
applies_to: [swift-buffer-primitives, swift-hash-table-primitives]
normative: false
---
-->

## Context

Buffer.Ring, Buffer.Linear, Buffer.Linked, Buffer.Slab, and Buffer.Arena all follow a consistent internal pattern:

1. **Static methods** for core operations taking `header: inout Header` and `storage: Storage<...>` — the logic lives in static methods, instance methods delegate to them.
2. **`ensureUnique()` semantics** — checks `isKnownUniquelyReferenced`, copies if shared, returns `true` if a copy was made.
3. **`copy()` method** — produces an independent copy of the buffer with its own storage.

Buffer.Slots deviates from all three conventions. This was identified while aligning Buffer.Linked with the static method pattern (see [linked-cow-safe-overloads](linked-cow-safe-overloads.md)).

**Trigger**: [RES-012] Discovery — proactive consistency audit after aligning Buffer.Linked.

**Scope**: Package-specific (buffer-primitives + hash-table-primitives consumer).

## Question

Should Buffer.Slots be brought into alignment with the static method pattern and `ensureUnique()` convention used by all other buffer variants?

## Analysis

### Issue 1: `ensureUnique()` Semantics Are Inverted

Every buffer variant follows this contract:

```swift
// Ring, Linear, Linked, Arena, Slab
@discardableResult
public mutating func ensureUnique() -> Bool {
    if !isKnownUniquelyReferenced(&storage) {
        self = copy()
        return true   // copy WAS made
    }
    return false      // already unique
}
```

Buffer.Slots does:

```swift
// Slots — INVERTED
@discardableResult
public mutating func ensureUnique() -> Bool {
    isKnownUniquelyReferenced(&storage)
    // returns true = already unique (no copy), false = shared (no copy made either)
}
```

Two problems:
- **Return value is inverted**: `true` means "already unique" instead of "copy was made."
- **No copy is performed**: The doc comment says "the caller is responsible for copying when `ensureUnique()` returns `false`." Every other variant handles the copy internally.

This is the only buffer where `ensureUnique()` does not actually ensure uniqueness.

### Issue 2: No `copy()` Method

Ring, Linear, Linked, Arena all provide:

```swift
@usableFromInline
package func copy() -> Self
```

Buffer.Slots has no `copy()`. This is required to implement the standard `ensureUnique()`.

### Issue 3: Hash.Table Consumer Is Broken

`Hash.Table+ensureUnique.swift:28` calls:

```swift
if !_buffer.isStorageUnique() {
```

`isStorageUnique()` does not exist on `Buffer.Slots`. This is a compile error in the `where Element: Copyable` extension. Hash.Table works around Buffer.Slots' non-standard `ensureUnique()` by implementing its own uniqueness check and manual copy — but the method it calls doesn't exist.

### Issue 4: Static Method Pattern

All other buffer variants extract core logic into static methods:

| Buffer | Static Methods File | Operations |
|--------|-------------------|-----------|
| Ring | `Buffer.Ring+Heap ~Copyable.swift` | pushBack, popFront, pushFront, popBack, deinitializeAll |
| Linear | `Buffer.Linear+Heap ~Copyable.swift` | append, removeFirst, remove(at:), replace(at:with:) |
| Linked | `Buffer.Linked+Pool ~Copyable.swift` | insertFront, insertBack, removeFront, removeBack, removeAll |
| Slab | `Buffer.Slab+Heap ~Copyable.swift` | insert, remove, update, forEachOccupied, deinitializeAll |
| Arena | `Buffer.Arena+Heap ~Copyable.swift` | allocate, insert, remove, forEach, deinitialize |
| **Slots** | **none** | — |

Buffer.Slots' operations (`initialize`, `move`, `deinitialize`, metadata subscript, `fill`, `withMetadataPointer`) are thin delegations to `Storage.Split`. The question is whether extracting these into statics provides value.

**Argument for**: The metadata-parametric-slots research already proposes Layer 2 static operations as the target design. Aligning now means the current code matches the planned architecture, and consumers like Hash.Table gain the option of calling statics directly (useful for growth/rehash where the consumer builds a new buffer from scratch).

**Argument against**: Buffer.Slots' header is immutable (`let capacity`). Static methods in other buffers take `header: inout Header` because operations mutate cursor state (count, head, etc.). Slots has no mutable cursor state — the metadata array IS the state, and it lives in storage. Static methods would take `header: Header` (not `inout`), breaking the pattern slightly. The operations are also one-liners — the static methods would add a layer of indirection with no logic.

### Comparison

| Criterion | Align | Keep as-is |
|-----------|-------|-----------|
| `ensureUnique()` contract | Matches all 5 other buffers | Inverted semantics, unique to Slots |
| `copy()` method | Consistent API surface | Missing |
| Hash.Table compile error | Fixed by adding proper `ensureUnique()` | Broken (`isStorageUnique()` undefined) |
| Static methods | Consistent file structure | One-liner delegations add indirection |
| Metadata-parametric-slots alignment | Matches proposed Layer 2 design | Diverges from planned architecture |
| Code complexity | Minimal — operations are trivial | Slightly less code |

## Outcome

**Status**: RECOMMENDATION

### Fix `ensureUnique()` and `copy()` — MUST

The inverted `ensureUnique()` semantics and missing `copy()` are bugs, not design choices. They contradict the universal buffer contract and break the Hash.Table consumer.

**Implementation**:

1. Add `copy()` to `Buffer.Slots Copyable.swift`:
   ```swift
   @usableFromInline
   package func copy() -> Self {
       Self(header: header, storage: storage.copy())
   }
   ```

2. Rewrite `ensureUnique()` to match the standard contract:
   ```swift
   @inlinable
   @discardableResult
   public mutating func ensureUnique() -> Bool {
       if !isKnownUniquelyReferenced(&storage) {
           self = copy()
           return true
       }
       return false
   }
   ```

3. Fix Hash.Table's `ensureUnique()` to use the buffer's method:
   ```swift
   // Before:
   if !_buffer.isStorageUnique() { ... manual copy ... }

   // After:
   _buffer.ensureUnique()
   ```

   Hash.Table's manual bulk-copy logic (`withMutableMetadataPointer` + payload loop) can be replaced by `_buffer.ensureUnique()` which calls `storage.copy()` — Storage.Split.copy() should handle this correctly as a bulk memory copy.

### Static Methods — DEFER

Static methods for Buffer.Slots should be **deferred** until the metadata-parametric-slots redesign is implemented. Rationale:

1. The current operations are one-liner delegations to Storage.Split. Static methods would add a redirection layer with no logic to extract.
2. Header is immutable — static methods would take `header: Header` (not `inout`), which is an unusual pattern relative to the other buffers.
3. The metadata-parametric-slots research proposes a redesigned type (`Buffer.Slots<Metadata, Payload>`) with a proper Layer 2 static operations tier. Implementing statics now on the current type would be throwaway work.
4. The primary motivation for statics (breaking Copyable/~Copyable overload recursion) doesn't apply — Slots has no Copyable overloads of mutation methods.

When the metadata-parametric-slots redesign lands, static methods should be part of the new type from the start.

## References

- [linked-cow-safe-overloads](linked-cow-safe-overloads.md) — trigger for this audit
- [buffer-variant-parity-analysis](buffer-variant-parity-analysis.md) — broader parity audit
- [metadata-parametric-slots](metadata-parametric-slots.md) — planned redesign with Layer 2 statics
