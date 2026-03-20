extension Buffer.Ring where Element: ~Copyable {
    // MARK: - Inline (Fixed-Capacity, Stack-Allocated)

    /// A fixed-capacity ring buffer backed by inline (stack-allocated) storage.
    ///
    /// Uses `Storage<Element>.Inline<capacity>` for stack-based allocation
    /// and the runtime `Header` for ring state tracking.
    ///
    /// Element cleanup is handled by deinit, which iterates the
    /// per-slot bitvector in `Storage.Inline` to deinitialize all
    /// initialized elements.
    public struct Inline<let capacity: Int>: ~Copyable {
        // WORKAROUND: Enum wrapping for @_rawLayout storage to avoid LLVM verifier
        // crash in release builds. ~Copyable structs with @_rawLayout stored fields
        // + explicit deinit trigger "Instruction does not dominate all uses!".
        // See Buffer.Ring.Small for extended rationale.
        @usableFromInline
        package enum _StorageRepr: ~Copyable, @unchecked Sendable {
            case active(Storage<Element>.Inline<capacity>)
        }

        @usableFromInline
        package var header: Header

        @usableFromInline
        package var _storage: _StorageRepr

        @usableFromInline
        package var storage: Storage<Element>.Inline<capacity> {
            _read {
                switch _storage {
                case .active(borrowing s):
                    yield s
                }
            }
        }

        @inlinable
        package init(header: Header, storage: consuming Storage<Element>.Inline<capacity>) {
            self.header = header
            self._storage = .active(storage)
        }

        deinit {
            guard case .active(var storage) = _storage else { return }
            unsafe storage.deinitialize()
        }

        /// Errors that can occur during inline ring buffer operations.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// The number of elements exceeds the buffer's capacity.
            case capacityExceeded
        }
    }
}

// Copyable suppressed per INV-INLINE-004a.
// extension Buffer.Ring.Inline: Copyable where Element: Copyable {}
// extension Buffer.Ring.Inline: Swift.Sequence where Element: Copyable {}
extension Buffer.Ring.Inline: Sendable where Element: Sendable {}
