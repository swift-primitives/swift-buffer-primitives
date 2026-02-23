public import Sequence_Primitives






// MARK: - Extensions for Ring (declared in Core)

extension Buffer.Ring where Element: ~Copyable {

    /// Creates a growable ring buffer with at least the given capacity.
    ///
    /// The actual capacity may be larger than requested per H6 —
    /// `header.capacity` is set from `storage.slotCapacity`.
    @inlinable
    public init(minimumCapacity: Index<Element>.Count) {
        let storage = Storage<Element>.Heap.create(minimumCapacity: minimumCapacity)
        self.init(
            header: Buffer.Ring.Header(capacity: storage.slotCapacity),
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
        // Move elements to new storage in linearized order
        header.initialization.linearize { range, offset in
            storage.move(range: range, to: newStorage, at: offset)
        }
        let oldCount = header.count
        storage.initialization = .empty
        storage = newStorage
        header = Buffer.Ring.Header(capacity: newStorage.slotCapacity)
        header.count = oldCount
        // head is 0 after linearization
        storage.initialization = header.initialization
    }

    /// Reduces capacity to match the current count, releasing unused memory.
    ///
    /// After calling this method, `capacity == count`. The ring buffer is
    /// linearized during compaction.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func compact() {
        guard header.count < header.capacity else { return }
        if header.isEmpty {
            storage = Storage<Element>.Heap.create(minimumCapacity: .zero)
            header = .init(capacity: storage.slotCapacity)
            return
        }
        _growTo(header.count)
    }
}

// MARK: - Tag Types

extension Buffer.Ring where Element: ~Copyable {
    /// Tag type for `.push` property extensions.
    public enum Push {
        public typealias View = Property<Push, Buffer<Element>.Ring>.View.Typed<Element>
    }

    /// Tag type for `.pop` property extensions.
    public enum Pop {
        public typealias View = Property<Pop, Buffer<Element>.Ring>.View.Typed<Element>
    }

    /// Tag type for `.peek` property extensions.
    public enum Peek {
        public typealias View = Property<Peek, Buffer<Element>.Ring>.View.Read.Typed<Element>
    }

    /// Tag type for `.remove` property extensions.
    public enum Remove {
        public typealias View = Property<Remove, Buffer<Element>.Ring>.View.Typed<Element>
    }
}

// MARK: - Internal Mutations

extension Buffer.Ring where Element: ~Copyable {

    @usableFromInline
    package mutating func _pushBack(_ element: consuming Element) {
        if header.isFull { _grow() }
        Buffer.Ring.pushBack(consume element, header: &header, storage: storage)
    }

    @usableFromInline
    package mutating func _popFront() -> Element {
        Buffer.Ring.popFront(header: &header, storage: storage)
    }

    @usableFromInline
    package mutating func _pushFront(_ element: consuming Element) {
        if header.isFull { _grow() }
        Buffer.Ring.pushFront(consume element, header: &header, storage: storage)
    }

    @usableFromInline
    package mutating func _popBack() -> Element {
        Buffer.Ring.popBack(header: &header, storage: storage)
    }

    @usableFromInline
    package mutating func _removeAll() {
        Buffer.Ring.deinitializeAll(header: &header, storage: storage)
    }
}

// MARK: - Property.View.Typed (.push, .pop, .peek, .remove)

extension Buffer.Ring where Element: ~Copyable {
    /// Namespaced push operations.
    ///
    /// - `buffer.push.back(element)` — pushes to the back.
    /// - `buffer.push.front(element)` — pushes to the front.
    @inlinable
    public var push: Push.View {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: Push.View = unsafe .init(&self)
            yield &view
        }
    }

    /// Namespaced pop operations.
    ///
    /// - `buffer.pop.front()` — pops from the front.
    /// - `buffer.pop.back()` — pops from the back.
    @inlinable
    public var pop: Pop.View {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: Pop.View = unsafe .init(&self)
            yield &view
        }
    }

    /// Namespaced peek operations (read-only).
    ///
    /// - `buffer.peek.front` — peeks at the front element.
    /// - `buffer.peek.back` — peeks at the back element.
    @inlinable
    public var peek: Peek.View {
        _read {
            yield Peek.View(borrowing: self)
        }
    }

    /// Namespaced remove operations.
    ///
    /// - `buffer.remove.all()` — removes all elements.
    /// - `buffer.remove.all(keepingCapacity:)` — removes all with capacity option.
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

// MARK: - Push Operations (~Copyable)

extension Property.View.Typed
where Tag == Buffer<Element>.Ring.Push,
      Base == Buffer<Element>.Ring,
      Element: ~Copyable
{
    /// Pushes an element to the back of the ring.
    ///
    /// Grows the buffer if full.
    /// - Complexity: O(1) amortized
    @_lifetime(&self)
    @inlinable
    public mutating func back(_ element: consuming Element) {
        unsafe base.pointee._pushBack(consume element)
    }

    /// Pushes an element to the front of the ring.
    ///
    /// Grows the buffer if full.
    /// - Complexity: O(1) amortized
    @_lifetime(&self)
    @inlinable
    public mutating func front(_ element: consuming Element) {
        unsafe base.pointee._pushFront(consume element)
    }
}

// MARK: - Pop Operations (~Copyable)

extension Property.View.Typed
where Tag == Buffer<Element>.Ring.Pop,
      Base == Buffer<Element>.Ring,
      Element: ~Copyable
{
    /// Removes and returns the element at the front of the ring.
    ///
    /// - Precondition: The buffer is not empty.
    /// - Complexity: O(1)
    @_lifetime(&self)
    @inlinable
    public mutating func front() -> Element {
        unsafe base.pointee._popFront()
    }

    /// Removes and returns the element at the back of the ring.
    ///
    /// - Precondition: The buffer is not empty.
    /// - Complexity: O(1)
    @_lifetime(&self)
    @inlinable
    public mutating func back() -> Element {
        unsafe base.pointee._popBack()
    }
}

// MARK: - Remove Operations (~Copyable)

extension Property.View.Typed
where Tag == Buffer<Element>.Ring.Remove,
      Base == Buffer<Element>.Ring,
      Element: ~Copyable
{
    /// Removes all elements from the buffer.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @_lifetime(&self)
    @inlinable
    public mutating func all() {
        unsafe base.pointee._removeAll()
    }
}

// MARK: - Sequence.Drain.Protocol

extension Buffer.Ring: Sequence.Drain.`Protocol` where Element: Copyable {
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        while !isEmpty {
            body(_popFront())
        }
    }
}

// MARK: - Sequence.Clearable

extension Buffer.Ring: Sequence.Clearable where Element: Copyable {
    @inlinable
    public mutating func removeAll() {
        _removeAll()
    }
}

// MARK: - Property.View (.drain)

extension Buffer.Ring where Element: ~Copyable {
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
