// MARK: - Copyable Conformances for Linear

extension Buffer.Linear where Element: Copyable {

    /// Returns the first element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var peekFront: Element {
        unsafe storage.pointer(at: .zero).pointee
    }

    /// Returns the last element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var peekBack: Element {
        let lastIdx = Index<Storage>(Ordinal(header.count.rawValue.rawValue &- 1))
        return unsafe storage.pointer(at: lastIdx).pointee
    }

    /// Ensures this buffer has unique storage (copy-on-write).
    @inlinable
    mutating func _makeUnique() {
        if !isKnownUniquelyReferenced(&storage) {
            let newStorage = Storage.Heap<Element>.create(minimumCapacity: header.capacity)
            Buffer.Linear<Element>.copy(header: header, source: storage, to: newStorage)
            let oldCount = header.count
            storage = newStorage
            header = Buffer.Linear<Element>.Header(capacity: newStorage.slotCapacity)
            header.count = oldCount
            storage.initialization = header.initialization
        }
    }
}

// MARK: - Property.View (.forEach)

extension Buffer.Linear where Element: Copyable {
    @inlinable
    public var forEach: Property<Sequence.ForEach, Self>.View {
        mutating _read {
            yield unsafe Property<Sequence.ForEach, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.ForEach, Self>.View(&self)
            yield &view
        }
    }
}
