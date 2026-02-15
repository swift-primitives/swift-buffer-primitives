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
        switch _storage {
        case .heap(var buf):
            let copied = buf.ensureUnique()
            self = Self(_storage: .heap(consume buf))
            return copied
        case .inline(var buf):
            self = Self(_storage: .inline(consume buf))
            return false  // inline is always unique
        }
    }
}
