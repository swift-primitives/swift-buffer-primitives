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
        // WORKAROUND: _modify temporarily removed — compiler crash in DiagnoseStaticExclusivity
        // WHY: yield through pointer into @frozen ~Copyable enum payload triggers signal 11
        // WHEN TO REMOVE: When Swift compiler fix lands
        // TRACKING: Same root cause as span crash
        //
        // _modify {
        //     switch _storage {
        //     case .heap(let heap):
        //         yield unsafe &heap.storage.pointer(at: index).pointee
        //     case .inline(let buf):
        //         let bounded = Index<Element>.Bounded<inlineCapacity>(index)!
        //         yield unsafe &buf.storage.pointer(at: bounded).pointee
        //     }
        // }
    }
}
