// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Storage_Primitives

// MARK: - Cyclic Index Overloads

extension Storage.Static where Element: ~Copyable {

    /// Converts a cyclic index to a linear index for internal operations.
    @inlinable
    public func linearIndex<let N: Int>(from cyclicIndex: Index<Element>.Cyclic<N>) -> Index<Element> {
        Index<Element>(Ordinal(cyclicIndex.rawValue.position.rawValue))
    }

    /// Returns an immutable pointer to the element at the given cyclic index.
    ///
    /// - Parameter index: The cyclic index of the element.
    /// - Returns: A pointer to the element.
    /// - Precondition: The element at `index` must be initialized.
    @inlinable
    public mutating func pointer<let N: Int>(at index: Index<Element>.Cyclic<N>) -> UnsafePointer<Element> {
        unsafe pointer(at: linearIndex(from: index))
    }

    /// Returns a mutable pointer to the element at the given cyclic index.
    ///
    /// - Parameter index: The cyclic index of the element.
    /// - Returns: A mutable pointer to the element.
    /// - Precondition: The element at `index` must be initialized.
    @inlinable
    public mutating func pointer<let N: Int>(at index: Index<Element>.Cyclic<N>) -> UnsafeMutablePointer<Element> {
        unsafe pointer(at: linearIndex(from: index))
    }

    /// Initializes storage at the given cyclic index with the provided value.
    ///
    /// - Parameters:
    ///   - value: The value to store.
    ///   - index: The cyclic index to initialize.
    /// - Precondition: The element at `index` must be uninitialized.
    @inlinable
    public mutating func initialize<let N: Int>(to value: consuming Element, at index: Index<Element>.Cyclic<N>) {
        initialize(to: value, at: linearIndex(from: index))
    }

    /// Moves the element at the given cyclic index, deinitializing that slot.
    ///
    /// - Parameter index: The cyclic index to move from.
    /// - Returns: The moved element.
    /// - Precondition: The element at `index` must be initialized.
    @inlinable
    public mutating func move<let N: Int>(at index: Index<Element>.Cyclic<N>) -> Element {
        move(at: linearIndex(from: index))
    }

    /// Provides access to the element at the given cyclic index via closure.
    ///
    /// - Parameters:
    ///   - index: The cyclic index of the element.
    ///   - body: A closure that receives a borrowed reference to the element.
    /// - Returns: The value returned by the closure.
    /// - Precondition: The element at `index` must be initialized.
    @inlinable
    public func withElement<let N: Int, R, E: Swift.Error>(
        at index: Index<Element>.Cyclic<N>,
        _ body: (borrowing Element) throws(E) -> R
    ) throws(E) -> R {
        try withElement(at: linearIndex(from: index), body)
    }

    /// Provides mutable access to the element at the given cyclic index via closure.
    ///
    /// - Parameters:
    ///   - index: The cyclic index of the element.
    ///   - body: A closure that receives a mutable reference to the element.
    /// - Returns: The value returned by the closure.
    /// - Precondition: The element at `index` must be initialized.
    @inlinable
    public mutating func withMutableElement<let N: Int, R, E: Swift.Error>(
        at index: Index<Element>.Cyclic<N>,
        _ body: (inout Element) throws(E) -> R
    ) throws(E) -> R {
        try withMutableElement(at: linearIndex(from: index), body)
    }

    /// Deinitializes elements using a cyclic header.
    ///
    /// - Parameter header: The cyclic ring buffer header.
    /// - Precondition: Elements from head through count positions must be initialized.
    /// - Note: Non-mutating to allow use from deinit contexts.
    @inlinable
    public func deinitialize<let N: Int>(header: Buffer<Element>.Ring.Header.Cyclic<N>) {
        deinitialize(head: header.headIndex, count: header.count)
    }
}
