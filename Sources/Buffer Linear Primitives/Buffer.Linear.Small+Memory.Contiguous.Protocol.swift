// MARK: - Memory.Contiguous.Protocol Conformance for Linear.Small

extension Buffer.Linear.Small: Memory.Contiguous.`Protocol` where Element: Copyable {
    /// Unsafe read access for C interop with unannotated APIs.
    ///
    /// Uses `switch` for borrowing access to `_heapBuffer` (SE-0432).
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        switch _heapBuffer {
        case .some(let heap):
            return try unsafe heap.withUnsafeBufferPointer(body)
        case .none:
            return try unsafe _inlineBuffer.withUnsafeBufferPointer(body)
        }
    }
}

// MARK: - Mutable Access

extension Buffer.Linear.Small where Element: Copyable {
    /// Unsafe mutable access for C interop with unannotated APIs.
    @inlinable
    public mutating func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        if _heapBuffer != nil {
            return try unsafe heap.withUnsafeMutableBufferPointer(body)
        } else {
            return try unsafe _inlineBuffer.withUnsafeMutableBufferPointer(body)
        }
    }
}
