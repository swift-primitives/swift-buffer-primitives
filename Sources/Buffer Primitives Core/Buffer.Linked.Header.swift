import Link_Primitives

extension Buffer.Linked where Element: ~Copyable {

    /// Pure cursor state for a linked list buffer.
    ///
    /// Typealias to `Link<N>.Header<Node>`. The canonical implementation
    /// lives in swift-link-primitives; this alias preserves the
    /// `Buffer<Element>.Linked<N>.Header` spelling for existing consumers.
    public typealias Header = Link<N>.Header<Node>

    /// Errors that can occur during linked list operations.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The number of elements exceeds the buffer's capacity.
        case capacityExceeded
    }
}
