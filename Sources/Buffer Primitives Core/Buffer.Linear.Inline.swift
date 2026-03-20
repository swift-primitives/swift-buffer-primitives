extension Buffer.Linear where Element: ~Copyable {

    /// A fixed-capacity linear buffer backed by inline (stack-allocated) storage.
    ///
    /// Uses `Storage<Element>.Inline<capacity>` for stack-based allocation
    /// and the runtime `Header` for linear state tracking.
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
                guard case .active(let s) = _storage else { preconditionFailure() }
                yield s
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

        /// Errors that can occur during inline linear buffer operations.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// The number of elements exceeds the buffer's capacity.
            case capacityExceeded
        }
    }
}

// MARK: - Conditional Conformances

// Copyable suppressed per INV-INLINE-004a.
// extension Buffer.Linear.Inline: Copyable where Element: Copyable {}
// extension Buffer.Linear.Inline: Swift.Sequence where Element: Copyable {}
extension Buffer.Linear.Inline: Sendable where Element: Sendable {}
