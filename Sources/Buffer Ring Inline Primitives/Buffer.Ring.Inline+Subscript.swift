// MARK: - Subscript for Ring.Inline (~Copyable)

extension Buffer.Ring.Inline where Element: ~Copyable {
    /// Accesses the element at the given logical index.
    ///
    /// Logical index 0 is the front of the ring. Physical slot is computed
    /// via `Index.Modular.physical(forLogical:head:capacity:)`.
    ///
    /// - Parameter index: The logical index of the element to access.
    @inlinable
    public subscript(index: Index<Element>) -> Element {
        _read {
            let bounded = Index<Element>.Bounded<capacity>(
                Index.Modular.physical(
                    forLogical: index, head: header.head, capacity: header.capacity)
            )!
            let ptr: UnsafePointer<Element> = unsafe storage.pointer(at: bounded)
            yield unsafe ptr.pointee
        }
        _modify {
            let bounded = Index<Element>.Bounded<capacity>(
                Index.Modular.physical(
                    forLogical: index, head: header.head, capacity: header.capacity)
            )!
            yield unsafe &storage.pointer(at: bounded).pointee
        }
    }
}
