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
        let count = Int(bitPattern: header.count.rawValue.rawValue)
        return try unsafe body(UnsafeBufferPointer(
            start: count > 0 ? UnsafePointer(storage.pointer(at: .zero)) : nil,
            count: count
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
        let count = Int(bitPattern: header.count.rawValue.rawValue)
        return try unsafe body(UnsafeMutableBufferPointer(
            start: count > 0 ? UnsafeMutablePointer(mutating: storage.pointer(at: .zero)) : nil,
            count: count
        ))
    }
}
