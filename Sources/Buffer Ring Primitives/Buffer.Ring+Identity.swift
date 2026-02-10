// MARK: - Buffer Identity for Ring

extension Buffer.Ring where Element: Copyable {
    /// The identity of the underlying heap storage object.
    ///
    /// Two Ring values share the same `bufferIdentity` if and only if they
    /// reference the same heap allocation (i.e., one is a copy of the other
    /// before any mutation triggered CoW).
    @inlinable
    public var bufferIdentity: ObjectIdentifier { ObjectIdentifier(storage) }
}

// MARK: - Buffer Identity for Ring.Bounded

extension Buffer.Ring.Bounded where Element: Copyable {
    /// The identity of the underlying heap storage object.
    ///
    /// Two Bounded values share the same `bufferIdentity` if and only if they
    /// reference the same heap allocation (i.e., one is a copy of the other
    /// before any mutation triggered CoW).
    @inlinable
    public var bufferIdentity: ObjectIdentifier { ObjectIdentifier(storage) }
}
