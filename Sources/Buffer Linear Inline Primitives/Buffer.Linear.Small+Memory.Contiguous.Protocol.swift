// MARK: - Memory.Contiguous.Protocol Conformance for Linear.Small

extension Buffer.Linear.Small: Memory.Contiguous.`Protocol` where Element: Copyable {
    /// Unsafe read access for C interop with unannotated APIs.
    ///
    /// Uses `switch` for borrowing access to `_storage` (SE-0432).
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        switch _storage {
        case .heap(let heap):
            return try unsafe heap.withUnsafeBufferPointer(body)
        case .inline(let buf):
            return try unsafe buf.withUnsafeBufferPointer(body)
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
        switch _storage {
        case .heap(var buf):
            do {
                let result = try unsafe buf.withUnsafeMutableBufferPointer(body)
                self = Self(_storage: .heap(consume buf))
                return result
            } catch {
                self = Self(_storage: .heap(consume buf))
                throw error
            }
        case .inline(var buf):
            do {
                let result = try unsafe buf.withUnsafeMutableBufferPointer(body)
                self = Self(_storage: .inline(consume buf))
                return result
            } catch {
                self = Self(_storage: .inline(consume buf))
                throw error
            }
        }
    }
}
