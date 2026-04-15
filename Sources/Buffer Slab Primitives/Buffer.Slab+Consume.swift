// MARK: - Sequence.Consume.Protocol for Slab

extension Buffer.Slab where Element: ~Copyable {
    /// State for consuming iteration — deinitializes remaining occupied slots on early exit.
    ///
    /// Class-based because `Sequence.Consume.Protocol.ConsumeState` must be Copyable,
    /// and cleanup-on-drop requires a deinit. The bitmap IS the consume state —
    /// linear scan provides destructive iteration through occupied slots.
    @safe
    public final class ConsumeState: @unsafe @unchecked Sendable {
        @usableFromInline
        let storage: Storage<Element>.Slab

        @usableFromInline
        var bitmap: Bit.Vector.Bounded

        @usableFromInline
        var onesIterator: Bit.Vector.Ones.Bounded.Iterator

        @inlinable
        package init(storage: Storage<Element>.Slab, bitmap: consuming Bit.Vector.Bounded) {
            self.storage = storage
            self.onesIterator = bitmap.ones.makeIterator()
            self.bitmap = bitmap
        }

        deinit {
            bitmap.ones.forEach { slot in
                storage.heap.deinitialize(at: slot.retag(Element.self))
            }
            // Sync empty bitmap to storage so Storage.Slab deinit is a no-op
            storage.bitmap = bitmap
        }
    }
}

extension Buffer.Slab: Sequence.Consume.`Protocol` where Element: Copyable {
    @inlinable
    public consuming func consume() -> Sequence.Consume.View<Element, ConsumeState> {
        // Take bitmap from header; sync empty bitmap to storage to disarm its deinit
        let consumeBitmap = header.bitmap.take()
        storage.bitmap = header.bitmap
        let state = ConsumeState(storage: storage, bitmap: consumeBitmap)
        return Sequence.Consume.View(
            state: state,
            next: { state in
                guard let slot = state.onesIterator.next() else { return nil }
                state.bitmap[slot] = false
                return state.storage.heap.move(at: slot.retag(Element.self))
            }
        )
    }
}
