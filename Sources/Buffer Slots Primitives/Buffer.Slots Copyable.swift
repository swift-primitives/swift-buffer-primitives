public import Buffer_Primitives_Core

// MARK: - Copy-on-Write Support (Copyable)

extension Buffer.Slots where Element: Copyable {
    /// Returns an independent copy of this buffer, copying only occupied elements.
    ///
    /// Metadata is bulk-copied. Elements are copied individually for slots
    /// where `isOccupied` returns `true`.
    ///
    /// - Parameter isOccupied: Returns `true` for metadata values that
    ///   indicate the corresponding element slot is initialized.
    @usableFromInline
    package func copy(where isOccupied: (Metadata) -> Bool) -> Self {
        let cap = header.capacity
        let newStorage = Storage<Element>.Split<Metadata>.create(capacity: cap)

        // Bulk-copy metadata (BitwiseCopyable — always fully initialized).
        unsafe newStorage.withMutablePointer(newStorage.laneField) { dst in
            unsafe storage.withPointer(storage.laneField) { src in
                unsafe dst.initialize(from: src, count: Int(bitPattern: cap))
            }
        }

        // Copy occupied elements individually.
        let laneField = storage.laneField
        let elementField = storage.elementField
        let newElementField = newStorage.elementField
        var slot: Index<Element> = .zero
        let end = cap.map(Ordinal.init)
        while slot < end {
            if isOccupied(storage[laneField, at: slot]) {
                unsafe newStorage.pointer(newElementField, at: slot).initialize(
                    to: storage[elementField, at: slot]
                )
            }
            slot += .one
        }

        return Self(header: header, storage: newStorage)
    }

    /// Ensures the underlying storage is uniquely referenced, copying if shared.
    ///
    /// Uses `isOccupied` to determine which element slots need copying.
    ///
    /// - Parameter isOccupied: Returns `true` for metadata values that
    ///   indicate the corresponding element slot is initialized.
    /// - Returns: `true` if a copy was made; `false` if already unique.
    @inlinable
    @discardableResult
    public mutating func ensureUnique(where isOccupied: (Metadata) -> Bool) -> Bool {
        if !isKnownUniquelyReferenced(&storage) {
            self = copy(where: isOccupied)
            return true
        }
        return false
    }
}

// MARK: - Copy-on-Write Support (BitwiseCopyable)

extension Buffer.Slots where Element: BitwiseCopyable {
    /// Returns an independent copy of this buffer using bulk memory copy.
    ///
    /// Both metadata and element arrays are copied in their entirety.
    /// This is the fast path for `BitwiseCopyable` elements where
    /// no per-slot initialization tracking is needed.
    @usableFromInline
    package func copy() -> Self {
        let cap = header.capacity
        let newStorage = Storage<Element>.Split<Metadata>.create(capacity: cap)
        let capInt = Int(bitPattern: cap)

        // Bulk-copy metadata.
        unsafe newStorage.withMutablePointer(newStorage.laneField) { dst in
            unsafe storage.withPointer(storage.laneField) { src in
                unsafe dst.initialize(from: src, count: capInt)
            }
        }

        // Bulk-copy elements (BitwiseCopyable: all bit patterns valid).
        let srcPtr: UnsafePointer<Element> = unsafe storage.pointer(storage.elementField, at: .zero)
        let dstPtr = unsafe newStorage.pointer(newStorage.elementField, at: .zero)
        unsafe dstPtr.initialize(from: srcPtr, count: capInt)

        return Self(header: header, storage: newStorage)
    }

    /// Ensures the underlying storage is uniquely referenced, copying if shared.
    ///
    /// Uses bulk memory copy — no occupancy predicate needed for
    /// `BitwiseCopyable` elements.
    ///
    /// - Returns: `true` if a copy was made; `false` if already unique.
    @inlinable
    @discardableResult
    public mutating func ensureUnique() -> Bool {
        if !isKnownUniquelyReferenced(&storage) {
            self = copy()
            return true
        }
        return false
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
