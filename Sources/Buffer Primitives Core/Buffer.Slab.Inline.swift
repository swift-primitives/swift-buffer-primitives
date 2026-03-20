import Index_Primitives

extension Buffer.Slab where Element: ~Copyable {
    // MARK: - Inline (Fixed-Capacity, Stack-Allocated)

    /// A fixed-capacity slab buffer backed by inline (stack-allocated) storage.
    ///
    /// Uses `Storage<Element>.Inline<wordCount>` for stack-based allocation
    /// and `Header.Static<wordCount>` for the bitmap.
    ///
    /// The bitmap drives cleanup — `Storage.Inline`'s initialization state
    /// stays `.empty`.
    public struct Inline<let wordCount: Int>: ~Copyable {
        // WORKAROUND: Enum wrapping for @_rawLayout storage to avoid LLVM verifier
        // crash in release builds. ~Copyable structs with @_rawLayout stored fields
        // + explicit deinit trigger "Instruction does not dominate all uses!".
        // See Buffer.Ring.Small for extended rationale.
        @usableFromInline
        package enum _StorageRepr: ~Copyable, @unchecked Sendable {
            case active(Storage<Element>.Inline<wordCount>)
        }

        @usableFromInline
        package var header: Header.Static<wordCount>

        @usableFromInline
        package var _storage: _StorageRepr

        @usableFromInline
        package var storage: Storage<Element>.Inline<wordCount> {
            _read {
                guard case .active(let s) = _storage else { preconditionFailure() }
                yield s
            }
        }

        @inlinable
        package init(
            header: Header.Static<wordCount>,
            storage: consuming Storage<Element>.Inline<wordCount>
        ) {
            self.header = header
            self._storage = .active(storage)
        }

        /// Errors that can occur during inline slab buffer operations.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// The number of elements exceeds the buffer's capacity.
            case capacityExceeded
        }

        deinit {
            guard case .active(var storage) = _storage else { return }
            // Bitmap-driven cleanup: Storage.Inline's initialization stays .empty,
            // so the bitmap is the sole source of truth for occupied slots.
            // Uses pointer-based deinit — non-mutating read of storage,
            // because deinit treats self as immutable.
            var slot: Bit.Index = .zero
            let end = Bit.Index.Count(UInt(wordCount)).map(Ordinal.init)
            while slot < end {
                if header.bitmap[slot] {
                    let elementSlot = Index<Element>.Bounded<wordCount>(slot.retag(Element.self))!
                    unsafe storage.pointer(at: elementSlot).deinitialize(count: 1)
                }
                slot += .one
            }
        }
    }
}

// Copyable suppressed per INV-INLINE-004a.
// extension Buffer.Slab.Inline: Copyable where Element: Copyable {}
// extension Buffer.Slab.Inline: Swift.Sequence where Element: Copyable {}
extension Buffer.Slab.Inline: Sendable where Element: Sendable {}
