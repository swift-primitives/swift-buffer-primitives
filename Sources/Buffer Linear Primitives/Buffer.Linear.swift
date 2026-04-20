public import Sequence_Primitives

// MARK: - Extensions for Linear (declared in Core)

extension Buffer.Linear where Element: ~Copyable {

    /// Creates a growable linear buffer with at least the given capacity.
    ///
    /// Actual capacity comes from `storage.slotCapacity` per H6.
    @inlinable
    public init(
        minimumCapacity: Index<Element>.Count
    ) {
        let storage = Storage<Element>.Heap.create(minimumCapacity: minimumCapacity)
        self.init(
            header: Buffer.Linear.Header(capacity: storage.slotCapacity),
            storage: storage
        )
    }

    /// The number of elements in the buffer.
    @inlinable
    public var count: Index<Element>.Count { header.count }

    /// Whether the buffer has no elements.
    @inlinable
    public var isEmpty: Bool { header.isEmpty }

    /// The total slot capacity.
    @inlinable
    public var capacity: Index<Element>.Count { header.capacity }

    /// Whether the buffer is at capacity.
    @inlinable
    public var isFull: Bool { header.isFull }

    // MARK: - Mutations

    /// Appends an element to the back of the buffer.
    ///
    /// Grows the buffer if full.
    @inlinable
    public mutating func append(_ element: consuming Element) {
        if header.isFull {
            _grow()
        }
        Buffer.Linear.append(consume element, header: &header, storage: storage)
    }

    /// Removes and returns the element at the given index, shifting subsequent elements left.
    ///
    /// - Precondition: The index must be in bounds.
    @inlinable
    public mutating func remove(at index: Index<Element>) -> Element {
        Buffer.Linear.remove(at: index, header: &header, storage: storage)
    }

    /// Replaces the element at the given index, returning the old element.
    ///
    /// - Precondition: The index must be in bounds.
    @inlinable
    public mutating func replace(at index: Index<Element>, with newElement: consuming Element) -> Element {
        Buffer.Linear.replace(at: index, with: consume newElement, storage: storage)
    }

    /// Swaps the elements at positions `i` and `j` in-place.
    ///
    /// - Precondition: Both indices must be in bounds.
    @inlinable
    public mutating func swap(at i: Index<Element>, with j: Index<Element>) {
        Buffer.Linear.swap(at: i, with: j, storage: storage)
    }

    /// Removes elements beyond the specified count.
    ///
    /// If `newCount >= count`, this method has no effect.
    @inlinable
    public mutating func truncate(to newCount: Index<Element>.Count) {
        Buffer.Linear.truncate(to: newCount, header: &header, storage: storage)
    }

    /// Ensures the buffer can hold at least `minimumCapacity` elements.
    @inlinable
    public mutating func reserveCapacity(_ minimumCapacity: Index<Element>.Count) {
        if minimumCapacity > header.capacity {
            _growTo(minimumCapacity)
        }
    }

    // MARK: - Growth (internal)

    @inlinable
    mutating func _grow() {
        if header.capacity == .zero {
            _growTo(.one)
        } else {
            _growTo(header.capacity * 2)
        }
    }

    @inlinable
    mutating func _growTo(_ minimumCapacity: Index<Element>.Count) {
        let newStorage = Storage<Element>.Heap.create(minimumCapacity: minimumCapacity)
        // Move elements to new storage — linear is always contiguous
        header.initialization.forEach { range in
            storage.move(range: range, to: newStorage)
        }
        let oldCount = header.count
        storage.initialization = .empty
        storage = newStorage
        header = Buffer.Linear.Header(capacity: newStorage.slotCapacity)
        header.count = oldCount
        storage.initialization = header.initialization
    }
}

// MARK: - Tag Types

extension Buffer.Linear where Element: ~Copyable {
    /// Tag type for `.peek` property extensions.
    public enum Peek {
        public typealias View = Property<Peek, Buffer<Element>.Linear>.View.Read.Typed<Element>
    }

    /// Tag type for `.remove` property extensions.
    public enum Remove {
        public typealias View = Property<Remove, Buffer<Element>.Linear>.View.Typed<Element>
    }
}

// MARK: - Internal Mutations

extension Buffer.Linear where Element: ~Copyable {

    @usableFromInline
    package mutating func _removeFirst() -> Element {
        Buffer.Linear.removeFirst(header: &header, storage: storage)
    }

    @usableFromInline
    package mutating func _removeLast() -> Element {
        Buffer.Linear.consumeBack(header: &header, storage: storage)
    }

    @usableFromInline
    package mutating func _removeAll() {
        Buffer.Linear.deinitializeAll(header: &header, storage: storage)
    }
}

// MARK: - Property.View (.peek, .remove)

extension Buffer.Linear where Element: ~Copyable {
    /// Namespaced peek operations (read-only).
    ///
    /// - `buffer.peek.front` — peeks at the first element.
    /// - `buffer.peek.back` — peeks at the last element.
    @inlinable
    public var peek: Peek.View {
        _read {
            yield Peek.View(self)
        }
    }

    /// Namespaced remove operations.
    ///
    /// - `buffer.remove.first()` — removes the first element.
    /// - `buffer.remove.last()` — removes the last element.
    /// - `buffer.remove.all()` — removes all elements.
    @inlinable
    public var remove: Remove.View {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: Remove.View = unsafe .init(&self)
            yield &view
        }
    }
}

// MARK: - Remove Operations (~Copyable)

extension Property.View.Typed
where Tag == Buffer<Element>.Linear.Remove,
      Base == Buffer<Element>.Linear,
      Element: ~Copyable
{
    /// Removes and returns the first element, shifting remaining elements left.
    ///
    /// - Precondition: The buffer is not empty.
    /// - Complexity: O(n)
    @inlinable
    public mutating func first() -> Element {
        unsafe base.pointee._removeFirst()
    }

    /// Removes and returns the last element.
    ///
    /// - Precondition: The buffer is not empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func last() -> Element {
        unsafe base.pointee._removeLast()
    }

    /// Removes all elements from the buffer.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func all() {
        unsafe base.pointee._removeAll()
    }
}

// MARK: - Sequence.Drain.Protocol

extension Buffer.Linear: Sequence.Drain.`Protocol` where Element: Copyable {
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        var position: Index<Element> = .zero
        let end = header.count.map(Ordinal.init)
        while position < end {
            body(storage.move(at: position))
            position += .one
        }
        header.count = .zero
        storage.initialization = header.initialization
    }
}

// MARK: - Sequence.Clearable

extension Buffer.Linear: Sequence.Clearable where Element: Copyable {
    @inlinable
    public mutating func removeAll() {
        _removeAll()
    }
}

// MARK: - Property.View (.drain)

extension Buffer.Linear where Element: ~Copyable {
    @inlinable
    public var drain: Property<Sequence.Drain, Self>.View {
        mutating _read {
            yield unsafe Property<Sequence.Drain, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Drain, Self>.View(&self)
            yield &view
        }
    }
}

