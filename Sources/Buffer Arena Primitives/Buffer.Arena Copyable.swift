// MARK: - Copy-on-Write Support

extension Buffer.Arena where Element: Copyable {

    /// Ensures the underlying storage is uniquely referenced, copying if needed.
    ///
    /// Returns `true` if a copy was made; `false` if already unique.
    @inlinable
    @discardableResult
    public mutating func ensureUnique() -> Bool {
        if !Swift.isKnownUniquelyReferenced(&storage) {
            _makeUnique()
            return true
        }
        return false
    }

    /// Creates an independent deep copy, preserving all slot indices and tokens.
    ///
    /// The copy has an identical occupied set, free-list state, and generation
    /// tokens. Slot indices used as cross-references (parent/child pointers in
    /// trees, next/prev in lists) remain valid in the copy.
    @usableFromInline
    package mutating func _makeUnique() {
        let newArenaStorage = Storage<Element>.Arena(minimumCapacity: header.capacity)
        let oldMeta = unsafe storage.metaBase
        let newMeta = unsafe newArenaStorage.metaBase
        let hw = Int(bitPattern: header.highWater)
        unsafe newMeta.update(from: oldMeta, count: hw)
        Buffer<Element>.Arena.forEach(occupied: header, meta: oldMeta) { slot in
            unsafe newArenaStorage.initialize(
                to: storage.elementPointer(at: slot).pointee, at: slot
            )
        }
        newArenaStorage.highWater = header.highWater
        self = Self(header: header, storage: newArenaStorage)
    }
}
