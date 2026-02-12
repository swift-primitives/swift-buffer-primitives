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

public import Buffer_Primitives_Core

// MARK: - Static Operations for ~Copyable Elements on Storage.Split

extension Buffer.Slots where Element: ~Copyable {

    // MARK: Initialize

    /// Initializes the element at the given slot.
    ///
    /// - Precondition: The slot must be uninitialized.
    @inlinable
    public static func initialize(
        to value: consuming Element,
        at slot: Index<Element>,
        storage: Storage<Element>.Split<Metadata>
    ) {
        storage.initialize(storage.elementField, to: value, at: slot)
    }

    // MARK: Move

    /// Moves the element out of the given slot, leaving it uninitialized.
    ///
    /// - Precondition: The slot must contain an initialized element.
    @inlinable
    public static func move(
        at slot: Index<Element>,
        storage: Storage<Element>.Split<Metadata>
    ) -> Element {
        storage.move(storage.elementField, at: slot)
    }

    // MARK: Deinitialize

    /// Deinitializes the element at the given slot.
    ///
    /// - Precondition: The slot must contain an initialized element.
    @inlinable
    public static func deinitialize(
        at slot: Index<Element>,
        storage: Storage<Element>.Split<Metadata>
    ) {
        storage.deinitialize(storage.elementField, at: slot)
    }

    // MARK: Deinitialize All

    /// Deinitializes element slots where metadata indicates occupancy.
    ///
    /// - Parameter isOccupied: Returns `true` for metadata values that
    ///   indicate the corresponding element slot is initialized.
    @inlinable
    public static func deinitializeAll(
        where isOccupied: (Metadata) -> Bool,
        header: Header,
        storage: Storage<Element>.Split<Metadata>
    ) {
        let laneField = storage.laneField
        let elementField = storage.elementField
        var slot: Index<Element> = .zero
        let end = header.capacity.map(Ordinal.init)
        while slot < end {
            if isOccupied(storage[laneField, at: slot]) {
                storage.deinitialize(elementField, at: slot)
            }
            slot += .one
        }
    }
}
