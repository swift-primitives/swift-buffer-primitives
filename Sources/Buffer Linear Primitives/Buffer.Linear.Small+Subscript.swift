// MARK: - Subscript for Linear.Small (~Copyable)

extension Buffer.Linear.Small where Element: ~Copyable {
    /// Accesses the element at the given index.
    ///
    /// Uses `switch` for `_read` (SE-0432 borrowing pattern matching)
    /// and force-unwrap for `_modify` (mutating context allows consume).
    ///
    /// - Parameter index: The index of the element to access.
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
                yield &_heapBuffer![index]
            } else {
                yield &_inlineBuffer[index]
            }
        }
    }
}
