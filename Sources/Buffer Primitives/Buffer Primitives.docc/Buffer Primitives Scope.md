# Buffer Primitives Scope

`swift-buffer-primitives` provides the **buffer-discipline substrate + the
foundational contiguous (Linear) buffer**. It owns the `Buffer<Element>`
namespace, the cross-discipline capacity-growth vocabulary, and the canonical
contiguous discipline (`Buffer.Linear`, with its Inline and Small satellites)
that Array, Stack, Heap, and Storage build on. Each specialized buffer
discipline (Ring, Slab, Linked, Slots, Arena, Unbounded, Aligned) is its own
sibling package.

## Per-[MOD-031] shape

The package follows `[MOD-031]` per-sub-namespace decomposition: `Buffer Primitive`
is the layer-invariant namespace target per `[MOD-017]`, and each retained
sub-namespace (`Buffer.Growth`, `Buffer.Linear`) is its own target. There is no
`Buffer Primitives Core` target — the legacy `[MOD-001]` Core convention is
deprecated and was retired from this package during the Cohort III extraction
(2026-05-23).

## Owner targets

- **Buffer Primitive** — the `public enum Buffer<S: ~Copyable> {}` namespace
  target. Zero external deps per `[MOD-017]`'s invariant.
- **Buffer Growth Primitives** — the `Buffer.Growth` namespace + `Buffer.Growth.Policy`
  capacity-growth strategy (`doubling` / `factor` / `exact` / `pageAligned`).
  Cross-discipline vocabulary shared by every growable discipline.
- **Buffer Linear Primitives** (+ Inline + Small satellites) — the foundational
  contiguous front-to-back discipline. `Buffer.Linear` is the canonical buffer the
  rest of the ecosystem's contiguous containers (Array, Stack, Heap, Storage) build
  on; it is retained here as the substrate's default form, not extracted.
- **Buffer Primitives** — umbrella; re-exports the retained sub-namespace targets so
  consumers needing the union write `import Buffer_Primitives`. Per `[MOD-032]` it does
  NOT re-export the extracted sibling disciplines (each sibling depends on this owner
  for the namespace + substrate; an owner→sibling re-export would form a package cycle).
- **Buffer Primitives Test Support** — published test-fixtures product.

## Out of scope (siblings)

Each specialized buffer discipline is its own sibling package. Each USES the
`Buffer Primitive` namespace + `Buffer Growth Primitives` (where growable) plus the
external substrate it requires.

- `Buffer.Ring` (circular FIFO/LIFO with wrap-around) → `swift-buffer-ring-primitives`
- `Buffer.Slab` (sparse index-addressable slot storage) → `swift-buffer-slab-primitives`
- `Buffer.Linked` (doubly-linked list over pool storage) → `swift-buffer-linked-primitives`
- `Buffer.Slots` (metadata-parametric random-access slots) → `swift-buffer-slots-primitives`
- `Buffer.Arena` (generation-token arena with O(1) alloc/free) → `swift-buffer-arena-primitives`
- `Buffer.Unbounded` (unbounded growable buffer; uses `Buffer.Aligned`) → `swift-buffer-unbounded-primitives`
- `Buffer.Aligned` (fixed-size, alignment-guaranteed byte buffer; conforms to
  `Span.Protocol` for direct I/O / SIMD / mmap) → `swift-buffer-aligned-primitives`

## Evaluation rule

Sub-target additions are evaluated against this scope.

- A proposed addition that is a **specialized buffer discipline** — a distinct way of
  organizing element storage (a ring, a slab, an arena, an alignment guarantee) —
  extracts to a sibling package, not into this one.
- A proposed addition that is **cross-discipline substrate** (the namespace, the
  growth-policy vocabulary, layout invariants) or part of the **foundational Linear
  discipline** lands as / within a retained sub-namespace target, per `[MOD-031]`.
