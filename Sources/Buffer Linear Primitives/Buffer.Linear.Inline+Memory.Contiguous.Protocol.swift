// MARK: - Memory.Contiguous.Protocol Conformance for Linear.Inline

extension Buffer.Linear.Inline: Memory.Contiguous.`Protocol` where Element: Copyable {
    /// Unsafe read access for C interop with unannotated APIs.
    ///
    /// Uses `header.count` as the authoritative element count
    /// (Inline buffers track initialization via the header, not `storage.initialization`).
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        return try unsafe body(UnsafeBufferPointer(
            start: !header.isEmpty ? UnsafePointer(storage.pointer(at: .zero)) : nil,
            count: header.count
        ))
    }
}

// MARK: - Type-Specific Mutable Access

extension Buffer.Linear.Inline where Element: Copyable {
    /// Unsafe mutable access for C interop with unannotated APIs.
    @inlinable
    public mutating func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        return try unsafe body(UnsafeMutableBufferPointer(
            start: !header.isEmpty ? UnsafeMutablePointer(mutating: storage.pointer(at: .zero)) : nil,
            count: header.count
        ))
    }
}
