import Vector_Primitives
import Index_Primitives

extension Buffer.Linked where Element: ~Copyable {

    /// A linked list node containing an element and N links.
    ///
    /// Nodes are stored in `Storage<Node>.Pool` slots. Links are
    /// `Index<Node>` values pointing to other slots in the same pool.
    /// Convention: `links[0]` = next, `links[1]` = prev (when N >= 2).
    /// The pool's sentinel marks end-of-list.
    ///
    /// `@frozen` because cross-module partial consumption of ~Copyable
    /// types requires known layout.
    @frozen
    public struct Node: ~Copyable {
        /// The element value stored in this node.
        public var element: Element

        /// Links to other nodes. `links[0]` = next, `links[1]` = prev (N >= 2).
        public var links: InlineArray<N, Index<Node>>

        /// Creates a node with the given element and links.
        @inlinable
        public init(element: consuming Element, links: InlineArray<N, Index<Node>>) {
            self.element = element
            self.links = links
        }
    }
}

// MARK: - Conditional Conformances (Linked.Node)

extension Buffer.Linked.Node: Copyable where Element: Copyable {}
extension Buffer.Linked.Node: @unchecked Sendable where Element: Sendable {}
