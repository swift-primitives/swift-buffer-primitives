import Link_Primitives

extension Buffer.Linked where Element: ~Copyable {

    /// A linked list node containing N links and an element.
    ///
    /// Typealias to `Link<N>.Node<Element>`. The canonical implementation
    /// lives in swift-link-primitives; this alias preserves the
    /// `Buffer<Element>.Linked<N>.Node` spelling for existing consumers.
    public typealias Node = Link<N>.Node<Element>
}
