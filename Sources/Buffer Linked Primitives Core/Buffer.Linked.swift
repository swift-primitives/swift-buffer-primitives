import Vector_Primitives
import Index_Primitives

extension Buffer where Element: ~Copyable {

    /// A linked list backed by pool storage, parameterized by link count.
    ///
    /// Uses `Storage<Node>.Pool` for O(1) node allocation/deallocation
    /// with slot reuse. Supports double-ended insert/remove operations.
    ///
    /// ## Link Count (N)
    ///
    /// - `Buffer<Element>.Linked<1>`: Singly-linked (next only, 1 link per node)
    /// - `Buffer<Element>.Linked<2>`: Doubly-linked (next + prev, 2 links per node)
    ///
    /// ## Pool-Backed Linked List
    ///
    /// Unlike Ring and Linear (contiguous) or Slab (sparse), Linked stores
    /// elements in pool-allocated nodes with explicit links.
    /// This provides O(1) insert/remove at both ends without shifting.
    ///
    /// ## Reference-Semantic Storage
    ///
    /// `Storage<Node>.Pool` is a `final class`, making the pool reference
    /// always Copyable. This enables `Buffer.Linked` to be conditionally
    /// Copyable when `Element: Copyable`, with CoW semantics via
    /// `isKnownUniquelyReferenced`.
    ///
    /// ## Node Layout
    ///
    /// Each node stores the element value plus `InlineArray<N, Index<Node>>` links.
    /// Convention: `links[0]` = next, `links[1]` = prev (when N >= 2).
    /// The pool's sentinel (`capacity.map(Ordinal.init)`) serves as the
    /// null link (end-of-list).
    ///
    /// ## Performance
    ///
    /// | Operation | N=1 (singly) | N=2 (doubly) |
    /// |-----------|:------------:|:------------:|
    /// | insertFront | O(1) | O(1) |
    /// | insertBack | O(1) | O(1) |
    /// | removeFront | O(1) | O(1) |
    /// | removeBack | O(n) traverse | O(1) |
    /// | forEach | O(n) | O(n) |
    /// | forEachReversed | N/A | O(n) |
    /// | Memory per node | Element + 1 Index | Element + 2 Index |
    ///
    /// ## Automatic Cleanup
    ///
    /// `Storage<Node>.Pool`'s deinit iterates `_allocationBits.ones` and
    /// deinitializes all allocated nodes (including their elements).
    /// No explicit cleanup is needed in `Buffer.Linked`.
    public struct Linked<let N: Int>: ~Copyable {
        @usableFromInline
        package var header: Header

        @usableFromInline
        package var storage: Storage<Node>.Pool

        @inlinable
        package init(header: Header, storage: Storage<Node>.Pool) {
            self.header = header
            self.storage = storage
        }
    }
}

// MARK: - Conditional Conformances (Linked)

extension Buffer.Linked: Copyable where Element: Copyable {}
/// Sendable conformance for `Buffer.Linked`.
///
/// ## Safety Invariant
///
/// `Buffer.Linked` is `~Copyable` and owns `Storage.Pool`. Single ownership
/// enforced; cross-thread transfer is a move.
///
/// ## Intended Use
///
/// - Transferring a pool-backed linked buffer to a worker thread.
///
/// ## Non-Goals
///
/// - Not a shared concurrent linked buffer.
extension Buffer.Linked: @unsafe @unchecked Sendable where Element: Sendable {}
