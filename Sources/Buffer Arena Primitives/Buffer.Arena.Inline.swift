public import Buffer_Primitives_Core

// MARK: - Extensions for Arena.Inline (declared in Core)

extension Buffer.Arena.Inline {

    /// Fully qualified Meta for cross-module use.
    @usableFromInline
    package typealias _Meta = Buffer<Element>.Arena.Meta

    // MARK: - Internal Pointer Helpers

    /// Pointer to the meta array. Valid for the lifetime of `self`.
    @unsafe
    @inlinable
    package mutating func _metaPointer() -> UnsafeMutablePointer<_Meta> {
        unsafe withUnsafeMutablePointer(to: &_meta) { ptr in
            unsafe UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: _Meta.self)
        }
    }

    /// Pointer to the element at the given slot.
    @unsafe
    @inlinable
    package mutating func _elementPointer(
        at slot: Index<Element>
    ) -> UnsafeMutablePointer<Element> {
        let offset = Int(bitPattern: slot) * MemoryLayout<Element>.stride
        return unsafe withUnsafeMutablePointer(to: &_elements) { rawPtr in
            unsafe UnsafeMutableRawPointer(rawPtr)
                .advanced(by: offset)
                .assumingMemoryBound(to: Element.self)
        }
    }

    // MARK: - Init

    /// Creates an empty inline arena with capacity `inlineCapacity`.
    @inlinable
    public init() {
        self.init(
            header: Buffer<Element>.Arena.Header(
                capacity: Index<Element>.Count(Cardinal(UInt(inlineCapacity)))
            ),
            _meta: InlineArray<inlineCapacity, _Meta>(repeating: .virgin),
            _elements: _Elements()
        )
    }

    // MARK: - Properties

    /// The number of currently occupied slots.
    @inlinable
    public var occupied: Index<Element>.Count { header.occupied }

    /// Whether no slots are occupied.
    @inlinable
    public var isEmpty: Bool { header.occupied == .zero }

    /// Whether the arena is full.
    @inlinable
    public var isFull: Bool { header.isFull }

    // MARK: - Insert

    /// Allocates a slot, initializes the element, and returns a Position handle.
    ///
    /// - Throws: `.full` if the arena has no available slots.
    @inlinable
    public mutating func insert(
        _ element: consuming Element
    ) throws(Error) -> Buffer<Element>.Arena.Position {
        guard !header.isFull else { throw .full }
        let meta = unsafe _metaPointer()
        let position = unsafe Buffer<Element>.Arena.allocate(header: &header, meta: meta)
        unsafe _elementPointer(at: position.slot).initialize(to: consume element)
        return position
    }

    /// Allocates a slot without initializing the element.
    ///
    /// - Throws: `.full` if the arena has no available slots.
    /// Caller MUST initialize the element at `position.slot` before use.
    @inlinable
    public mutating func allocate() throws(Error) -> Buffer<Element>.Arena.Position {
        guard !header.isFull else { throw .full }
        let meta = unsafe _metaPointer()
        let position = unsafe Buffer<Element>.Arena.allocate(header: &header, meta: meta)
        return position
    }

    // MARK: - Remove

    /// Validates the position, moves the element out, and releases the slot.
    ///
    /// - Throws: `.invalidPosition` if the position is stale or invalid.
    @inlinable
    public mutating func remove(
        at position: Buffer<Element>.Arena.Position
    ) throws(Error) -> Element {
        let meta = unsafe _metaPointer()
        guard unsafe Buffer<Element>.Arena.isValid(position, header: header, meta: meta) else {
            throw .invalidPosition
        }
        let element = unsafe _elementPointer(at: position.slot).move()
        unsafe Buffer<Element>.Arena._releaseSlot(position.index, header: &header, meta: meta)
        return element
    }

    /// Moves the element out of the given slot and releases the slot.
    ///
    /// - Precondition: `slot` is occupied.
    @inlinable
    public mutating func remove(at slot: Index<Element>) -> Element {
        let rawSlot = UInt32(slot.rawValue.rawValue)
        let meta = unsafe _metaPointer()
        precondition(unsafe meta[Int(rawSlot)].isOccupied, "Arena.Inline: slot is not occupied")
        let element = unsafe _elementPointer(at: slot).move()
        unsafe Buffer<Element>.Arena._releaseSlot(rawSlot, header: &header, meta: meta)
        return element
    }

    /// Deinitializes the element at the given slot and releases the slot.
    ///
    /// - Precondition: `slot` is occupied.
    @inlinable
    public mutating func free(at slot: Index<Element>) {
        let rawSlot = UInt32(slot.rawValue.rawValue)
        let meta = unsafe _metaPointer()
        precondition(unsafe meta[Int(rawSlot)].isOccupied, "Arena.Inline: slot is not occupied")
        unsafe _elementPointer(at: slot).deinitialize(count: 1)
        unsafe Buffer<Element>.Arena._releaseSlot(rawSlot, header: &header, meta: meta)
    }

    /// Deinitializes all occupied elements and resets the arena to empty state.
    @inlinable
    public mutating func removeAll() {
        let hw = Int(bitPattern: header.highWater)
        for i in 0..<hw {
            if _meta[i].isOccupied {
                unsafe _elementPointer(
                    at: Index<Element>(Ordinal(UInt(i)))
                ).deinitialize(count: 1)
                _meta[i].token &+= 1
            }
        }
        header.occupied = .zero
        header.freeHead = .max
        header.highWater = .zero
    }

    // MARK: - Validation

    /// Returns whether the given position handle is still valid.
    @inlinable
    public mutating func isValid(
        _ position: Buffer<Element>.Arena.Position
    ) -> Bool {
        let meta = unsafe _metaPointer()
        return unsafe Buffer<Element>.Arena.isValid(position, header: header, meta: meta)
    }

    /// Returns whether the slot at the given index is occupied.
    @inlinable
    public func isOccupied(_ slot: Index<Element>) -> Bool {
        _meta[Int(UInt32(slot.rawValue.rawValue))].isOccupied
    }

    // MARK: - Token Access

    /// Returns the current generation token for the given slot.
    @inlinable
    public func token(at slot: Index<Element>) -> UInt32 {
        _meta[Int(UInt32(slot.rawValue.rawValue))].token
    }

    /// Constructs a Position handle from an occupied slot.
    ///
    /// - Precondition: `slot` is occupied.
    @inlinable
    public mutating func position(
        forOccupied slot: Index<Element>
    ) -> Buffer<Element>.Arena.Position {
        let meta = unsafe _metaPointer()
        return unsafe Buffer<Element>.Arena.position(forOccupied: slot, meta: meta)
    }

    // MARK: - Element Access

    /// Pointer to the element at the given slot index.
    ///
    /// - Precondition: `slot` is within `[.zero, highWater)`.
    @unsafe
    @inlinable
    public mutating func pointer(
        at slot: Index<Element>
    ) -> UnsafeMutablePointer<Element> {
        unsafe _elementPointer(at: slot)
    }
}
