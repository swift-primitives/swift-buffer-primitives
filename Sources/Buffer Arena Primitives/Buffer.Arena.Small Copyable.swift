public import Buffer_Primitives_Core

// MARK: - Copy-on-Write Support

extension Buffer.Arena.Small where Element: Copyable {

    /// Ensures the underlying storage is uniquely referenced, copying if needed.
    ///
    /// Only applies to the heap path — inline storage is value-typed and
    /// always unique. Returns `true` if a copy was made; `false` if already
    /// unique or still inline.
    @inlinable
    @discardableResult
    public mutating func ensureUnique() -> Bool {
        guard _heapBuffer != nil else { return false }  // inline is always unique
        return _heapBuffer!.ensureUnique()
    }
}
