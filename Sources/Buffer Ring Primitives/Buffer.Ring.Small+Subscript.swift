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
            switch _heapBuffer {
            case .some(let heap):
                yield heap[index]
            case .none:
                yield _inlineBuffer[index]
            }
        }
        _modify {
            if _heapBuffer != nil {
                yield &heap[index]
            } else {
                yield &_inlineBuffer[index]
            }
        }
    }
}
