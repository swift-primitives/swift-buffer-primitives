// MARK: - Subscript for Linear.Small (~Copyable)

extension Buffer.Linear.Small where Element: ~Copyable {
    /// Accesses the element at the given index.
    ///
    /// Uses `switch` for both `_read` (SE-0432 borrowing pattern matching)
    /// and `_modify` (var binding with reassign).
    ///
    /// - Parameter index: The index of the element to access.
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
            // Inline case cannot yield through pointer into enum payload (borrow temporary).
            // Spill to heap first — mirrors Copyable variant's ensureUnique() pattern.
            // See: Experiments/small-enum-modify-recovery (2026-02-16)
            _spillToHeapMoving()
            switch _storage {
            case .heap(let heap):
                yield unsafe &heap.storage.pointer(at: index).pointee
            case .inline:
                fatalError("unreachable: _spillToHeapMoving guarantees heap mode")
            }
        }
    }
}
