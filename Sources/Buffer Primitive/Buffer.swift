/// Namespace for buffer primitives.
///
/// Buffer provides four disciplines for managing elements in storage:
/// - ``Buffer/Linear``: Contiguous front-to-back storage
/// - ``Buffer/Ring``: Circular FIFO/LIFO storage with wrap-around
/// - ``Buffer/Slots``: Metadata-parametric random-access slots
/// - ``Buffer/Linked``: Doubly-linked list backed by generational slot storage
///
/// Each discipline follows a three-layer architecture:
/// 1. **Header** — Pure cursor/bookkeeping state (Layer 1)
/// 2. **Static Operations** — Expert-level functions on the storage substrate (Layer 2)
/// 3. **Composed Types** — User-facing types that delegate to static ops (Layer 3)
///
/// The buffer-discipline namespace, parameterized by the STORAGE SUBSTRATE.
///
/// W3 ⑤-(N): the namespace parameter is the substrate `S` (a
/// `Storage.`Protocol`` conformer, constrained per-discipline-extension so this
/// root stays dependency-free per [MOD-017]). Disciplines read their element
/// through the substrate (`S.Element`); spellings are substrate-explicit:
/// `Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Job>>.Ring`.
/// Probe receipt: /tmp/msb-buffer-s-probe
/// (conditional Copyable + @_rawLayout under the reparam + 0-witness, all PASS).
public enum Buffer<S: ~Copyable> {}

// MARK: - Inline-backed composition (the former INV-INLINE-004a, resolved)
//
// `Store.Inline` (storage-primitives) is UNCONDITIONALLY `~Copyable`: its
// @_rawLayout cells and deinit oracle are only legal on a `~Copyable` type, so
// conditional `Copyable` became the explicit `copy()` (the Q2 transformation —
// see Store.Inline.swift). Inline-backed buffer compositions inherit that
// discipline: they compose move-only and copy explicitly. The dissolved
// spelling and the old per-variant Copyable-restoration list retired with the
// old world (remaining citers are the parked buffer-slab / buffer-arena
// packages, handled by their own dispositions).
