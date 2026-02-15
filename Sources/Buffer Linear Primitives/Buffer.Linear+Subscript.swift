// MARK: - Subscript for Linear (~Copyable)

extension Buffer.Linear where Element: ~Copyable {
    /// Accesses the element at the given index.
    ///
    /// - Parameter index: The index of the element to access.
    @inlinable
    public subscript(_ index: Index<Element>) -> Element {
        _read {
            yield unsafe storage.pointer(at: index).pointee
        }
        _modify {
            yield unsafe &storage.pointer(at: index).pointee
        }
    }
}
