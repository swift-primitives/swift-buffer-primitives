import Vector_Primitives
import Index_Primitives

/// Namespace for buffer primitives.
///
/// Buffer provides six disciplines for managing elements in storage:
/// - ``Buffer/Linear``: Contiguous front-to-back storage
/// - ``Buffer/Ring``: Circular FIFO/LIFO storage with wrap-around
/// - ``Buffer/Slab``: Sparse index-addressable slot storage
/// - ``Buffer/Linked``: Doubly-linked list backed by pool storage
/// - ``Buffer/Slots``: Metadata-parametric random-access slots
/// - ``Buffer/Arena``: Generation-token arena with O(1) alloc/free
///
/// Each discipline follows a three-layer architecture:
/// 1. **Header** — Pure cursor/bookkeeping state (Layer 1)
/// 2. **Static Operations** — Expert-level functions on `Storage.Heap` (Layer 2)
/// 3. **Composed Types** — User-facing types that delegate to static ops (Layer 3)
///
public enum Buffer<Element: ~Copyable> {}

// MARK: - INV-INLINE-004a: Storage.Inline Copyable Restriction
//
// Storage.Inline uses @_rawLayout which is unconditionally ~Copyable.
// @_rawLayout is required because InlineArray has no uninitialized API and
// requires Copyable for init(repeating:), but Storage.Inline must support
// ~Copyable elements. If Swift adds InlineArray.init(unsafeUninitializedCapacity:),
// Storage.Inline could migrate and Inline/Small Copyable conformances can be restored.
//
// Affected: Ring.Inline, Ring.Small, Linear.Inline, Linear.Small, Slab.Inline,
//           Linked.Inline, Linked.Small, Arena.Inline, Arena.Small.
