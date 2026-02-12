// MARK: - Subscript (Copyable with CoW)

extension Buffer.Linear where Element: Copyable {
    /// Accesses the element at the given index with copy-on-write semantics.
    ///
    /// - Parameter index: The index of the element to access.
    @inlinable
    public subscript(index: Index<Element>) -> Element {
        _read {
            yield unsafe storage.pointer(at: index).pointee
        }
        _modify {
            ensureUnique()
            yield unsafe &storage.pointer(at: index).pointee
        }
    }
}
