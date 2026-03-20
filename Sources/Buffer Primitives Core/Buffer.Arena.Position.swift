import Index_Primitives

extension Buffer.Arena where Element: ~Copyable {
    // MARK: - Position

    /// An external handle to a slot in an arena buffer.
    ///
    /// Compact 8-byte representation: `(index: UInt32, token: UInt32)`.
    /// The `slot` computed property provides typed `Index<Element>`
    /// at API boundaries per [IMPL-010].
    ///
    /// Phantom-typed via `Buffer<Element>` parameterization — handles
    /// from different arenas cannot be mixed at compile time.
    @frozen
    public struct Position: Copyable, Sendable, Equatable, Hashable {
        /// Compact slot coordinate (UInt32 for 8-byte handle).
        public let index: UInt32

        /// Generation at allocation time. Must match current token for validity.
        public let token: UInt32

        /// Creates a position handle with the given slot index and token.
        @inlinable
        public init(index: UInt32, token: UInt32) {
            self.index = index
            self.token = token
        }

        /// Typed slot index for API boundary use.
        @inlinable
        public var slot: Index<Element> {
            Index<Element>(Ordinal(UInt(index)))
        }
    }
}
