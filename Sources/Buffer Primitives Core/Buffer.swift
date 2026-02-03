/// Namespace for buffer primitives.
///
/// Buffer provides three disciplines for managing elements in storage:
/// - ``Buffer/Linear``: Contiguous front-to-back storage
/// - ``Buffer/Ring``: Circular FIFO/LIFO storage with wrap-around
/// - ``Buffer/Slab``: Sparse index-addressable slot storage
///
/// Each discipline follows a three-layer architecture:
/// 1. **Header** — Pure cursor/bookkeeping state (Layer 1)
/// 2. **Static Operations** — Expert-level functions on `Storage.Heap` (Layer 2)
/// 3. **Composed Types** — User-facing types that delegate to static ops (Layer 3)
public enum Buffer {}
