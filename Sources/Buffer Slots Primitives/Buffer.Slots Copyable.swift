public import Buffer_Primitives_Core

// MARK: - Storage Uniqueness

extension Buffer.Slots where Element: Copyable {
    /// Returns `true` if the underlying storage is uniquely referenced.
    ///
    /// Use this to implement copy-on-write for types that embed `Buffer.Slots`.
    @inlinable
    public mutating func isStorageUnique() -> Bool {
        isKnownUniquelyReferenced(&storage)
    }
}

// MARK: - Payload Subscript (Copyable Only)

extension Buffer.Slots where Element: Copyable {
    /// Reads or writes the element at the given slot.
    ///
    /// - Precondition: The slot must contain an initialized element.
    @inlinable
    public subscript(payload slot: Index<Element>) -> Element {
        get { storage[storage.elementField, at: slot] }
        set { storage[storage.elementField, at: slot] = newValue }
    }

    /// Fills all element slots with the given value.
    @inlinable
    public func fill(payload value: Element) {
        storage.fill(storage.elementField, with: value)
    }
}
