// MARK: - Subscript for Ring.Small (~Copyable)

extension Buffer.Ring.Small where Element: ~Copyable {
    /// Accesses the element at the given logical index.
    ///
    /// Routes to heap or inline buffer based on current storage mode.
    ///
    /// - Parameter index: The logical index of the element to access.
    @inlinable
    public subscript(index: Index<Element>) -> Element {
        _read {
            switch _storage {
            case .heap(let heap):
                yield heap[index]
            case .inline(let buf):
                yield buf[index]
            }
        }
        _modify {
            switch _storage {
            case .heap(let heap):
                let physical = Index.Modular.physical(
                    forLogical: index, head: heap.header.head, capacity: heap.header.capacity)
                yield unsafe &heap.storage.pointer(at: physical).pointee
            case .inline(let buf):
                let bounded = Index<Element>.Bounded<inlineCapacity>(
                    Index.Modular.physical(
                        forLogical: index, head: buf.header.head, capacity: buf.header.capacity)
                )!
                yield unsafe &buf.storage.pointer(at: bounded).pointee
            }
        }
    }
}
