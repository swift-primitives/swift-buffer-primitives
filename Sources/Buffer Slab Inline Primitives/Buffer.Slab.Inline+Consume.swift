// MARK: - Sequence.Consume support for Slab.Inline

extension Buffer.Slab.Inline where Element: ~Copyable {
    /// State for consuming iteration — deinitializes remaining occupied slots on early exit.
    ///
    /// Class-based because `Sequence.Consume.Protocol.ConsumeState` must be Copyable,
    /// and cleanup-on-drop requires a deinit.
    ///
    /// Elements are moved from inline storage to heap storage during `consume()`
    /// for safe iteration. The bitmap tracks remaining occupied slots.
    public final class ConsumeState: @unsafe @unchecked Sendable {
        @usableFromInline
        let storage: Storage<Element>.Heap

        @usableFromInline
        var bitmap: Bit.Vector.Static<wordCount>

        @usableFromInline
        let slotCount: Int

        @inlinable
        package init(
            storage: Storage<Element>.Heap,
            bitmap: Bit.Vector.Static<wordCount>,
            slotCount: Int
        ) {
            self.storage = storage
            self.bitmap = bitmap
            self.slotCount = slotCount
        }

        deinit {
            var slot: Bit.Index = .zero
            let end = Bit.Index.Count(UInt(slotCount)).map(Ordinal.init)
            while slot < end {
                if bitmap[slot] {
                    storage.deinitialize(at: slot.retag(Element.self))
                }
                slot += .one
            }
            storage.initialization = .empty
        }
    }
}

extension Buffer.Slab.Inline where Element: ~Copyable {
    /// Moves a single occupied slot from inline storage to heap storage.
    ///
    /// Isolated from the bitmap loop so CopyPropagation processes the
    /// storage move+initialize chain independently.
    @usableFromInline
    static func moveSlotToHeap(
        storage: inout Storage<Element>.Inline<wordCount>,
        heapStorage: Storage<Element>.Heap,
        at slot: Bit.Index
    ) {
        let element = storage.move(at: Index<Element>.Bounded<wordCount>(slot.retag(Element.self))!)
        heapStorage.initialize(to: element, at: slot.retag(Element.self))
    }
}

extension Buffer.Slab.Inline where Element: Copyable {
    /// Consumes the buffer's elements into a consuming view.
    ///
    /// Moves all occupied elements from inline storage to heap storage, then provides
    /// iteration via the returned view. The buffer is left empty.
    ///
    /// - Returns: A consuming view for element-by-element iteration.
    /// - Complexity: O(n) to create the view (element transfer). O(1) per element during iteration.
    @inlinable
    public mutating func consume() -> Sequence.Consume.View<Element, ConsumeState> {
        let bitmapCopy = header.bitmap
        let count = Bit.Index.Count(UInt(wordCount))
        let heapStorage = Storage<Element>.Heap.create(minimumCapacity: count.retag(Element.self))

        // Move occupied elements from inline to heap
        var slot: Bit.Index = .zero
        let end = count.map(Ordinal.init)
        while slot < end {
            if header.bitmap[slot] {
                Self.moveSlotToHeap(storage: &storage, heapStorage: heapStorage, at: slot)
                header.bitmap[slot] = false
            }
            slot += .one
        }

        return Sequence.Consume.View(
            state: ConsumeState(
                storage: heapStorage,
                bitmap: bitmapCopy,
                slotCount: wordCount
            ),
            next: { state in
                var slot: Bit.Index = .zero
                let end = Bit.Index.Count(UInt(state.slotCount)).map(Ordinal.init)
                while slot < end {
                    if state.bitmap[slot] {
                        state.bitmap[slot] = false
                        return state.storage.move(at: slot.retag(Element.self))
                    }
                    slot += .one
                }
                return nil
            }
        )
    }
}
