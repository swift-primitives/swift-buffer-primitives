// MARK: - Subscript for Linear.Inline (~Copyable)

extension Buffer.Linear.Inline where Element: ~Copyable {
    /// Accesses the element at the given index.
    ///
    /// - Parameter index: The index of the element to access.
    @inlinable
    public subscript(index: Index<Element>) -> Element {
        _read {
            yield unsafe storage.pointer(at: index).pointee
        }
        _modify {
            yield unsafe &storage.pointer(at: index).pointee
        }
    }
}
