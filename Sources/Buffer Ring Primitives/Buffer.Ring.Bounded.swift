// MARK: - Extensions for Ring.Bounded (declared in Core)

extension Buffer.Ring.Bounded where Element: ~Copyable {

    /// Creates a bounded ring buffer with at least the given capacity.
    ///
    /// Actual capacity comes from `storage.slotCapacity` per H6.
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
}

// MARK: - Tag View Typealiases

extension Buffer.Ring.Bounded where Element: ~Copyable {
    public enum Push {
        public typealias View = Property<Buffer<Element>.Ring.Push, Buffer<Element>.Ring.Bounded>.View.Typed<Element>
    }

    public enum Pop {
        public typealias View = Property<Buffer<Element>.Ring.Pop, Buffer<Element>.Ring.Bounded>.View.Typed<Element>
    }

    public enum Peek {
        public typealias View = Property<Buffer<Element>.Ring.Peek, Buffer<Element>.Ring.Bounded>.View.Read.Typed<Element>
    }

    public enum Remove {
        public typealias View = Property<Buffer<Element>.Ring.Remove, Buffer<Element>.Ring.Bounded>.View.Typed<Element>
    }
}

// MARK: - Internal Mutations

extension Buffer.Ring.Bounded where Element: ~Copyable {

    @usableFromInline
    package mutating func _pushBack(_ element: consuming Element) -> Element? {
        if header.isFull { return element }
        Buffer.Ring.pushBack(consume element, header: &header, storage: storage)
        return nil
    }

    @usableFromInline
    package mutating func _popFront() -> Element {
        Buffer.Ring.popFront(header: &header, storage: storage)
    }

    @usableFromInline
    package mutating func _pushFront(_ element: consuming Element) -> Element? {
        if header.isFull { return element }
        Buffer.Ring.pushFront(consume element, header: &header, storage: storage)
        return nil
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

extension Buffer.Ring.Bounded where Element: ~Copyable {
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

    @inlinable
    public var peek: Peek.View {
        mutating _read {
            yield unsafe .init(&self)
        }
    }

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
      Base == Buffer<Element>.Ring.Bounded,
      Element: ~Copyable
{
    /// Pushes an element to the back. Returns the element if the buffer is full.
    @_lifetime(&self)
    @inlinable
    @discardableResult
    public mutating func back(_ element: consuming Element) -> Element? {
        unsafe base.pointee._pushBack(consume element)
    }

    /// Pushes an element to the front. Returns the element if the buffer is full.
    @_lifetime(&self)
    @inlinable
    @discardableResult
    public mutating func front(_ element: consuming Element) -> Element? {
        unsafe base.pointee._pushFront(consume element)
    }
}

// MARK: - Pop Operations (~Copyable)

extension Property.View.Typed
where Tag == Buffer<Element>.Ring.Pop,
      Base == Buffer<Element>.Ring.Bounded,
      Element: ~Copyable
{
    /// Removes and returns the element at the front.
    ///
    /// - Precondition: The buffer is not empty.
    @_lifetime(&self)
    @inlinable
    public mutating func front() -> Element {
        unsafe base.pointee._popFront()
    }

    /// Removes and returns the element at the back.
    ///
    /// - Precondition: The buffer is not empty.
    @_lifetime(&self)
    @inlinable
    public mutating func back() -> Element {
        unsafe base.pointee._popBack()
    }
}

// MARK: - Remove Operations (~Copyable)

extension Property.View.Typed
where Tag == Buffer<Element>.Ring.Remove,
      Base == Buffer<Element>.Ring.Bounded,
      Element: ~Copyable
{
    /// Removes all elements from the buffer.
    @_lifetime(&self)
    @inlinable
    public mutating func all() {
        unsafe base.pointee._removeAll()
    }
}

// MARK: - Sequence.Drain.Protocol

extension Buffer.Ring.Bounded: Sequence.Drain.`Protocol` where Element: Copyable {
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        while !isEmpty {
            body(_popFront())
        }
    }
}

// MARK: - Sequence.Clearable

extension Buffer.Ring.Bounded: Sequence.Clearable where Element: Copyable {
    @inlinable
    public mutating func removeAll() {
        _removeAll()
    }
}

// MARK: - Property.View (.drain)

extension Buffer.Ring.Bounded where Element: ~Copyable {
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
