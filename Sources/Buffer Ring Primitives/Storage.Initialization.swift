//
//  File.swift
//  swift-buffer-primitives
//
//  Created by Coen ten Thije Boonkkamp on 04/02/2026.
//

import Buffer_Primitives_Core
import Storage_Primitives

extension Storage.Initialization where Element: ~Copyable {
    @inlinable
    public init(
        _ header: Buffer<Element>.Ring.Header
    ) {
        if header.count == .zero {
            self = .empty
            return
        }

        let tail = header.head + header.count

        if tail <= header.capacity {
            self = .one(header.head ..< tail)
        } else {
            self = .two(
                first: header.head ..< Index<Element>(__unchecked: (), Ordinal(header.capacity.rawValue)),
                second: .zero ..< Index<Element>(__unchecked: (), Ordinal(
                    Index<Element>.Count(tail).subtract.saturating(header.capacity).rawValue)
                )
            )
        }
    }
}

extension Storage.Initialization where Element: ~Copyable {
    @inlinable
    public init<let capacity: Int>(
        _ header: Buffer<Element>.Ring.Header.Cyclic<capacity>
    ) {
        if header.count == .zero {
            self = .empty
            return
        }

        let slotCapacity = Buffer<Element>.Ring.Header.Cyclic<capacity>.slotCapacity
        let headIndex = Index<Element>(__unchecked: (), Ordinal(header.head.rawValue))
        let tail = headIndex + header.count

        if tail <= slotCapacity {
            self = .one(headIndex ..< tail)
        } else {
            self = .two(
                first: headIndex ..< Index<Element>(__unchecked: (), Ordinal(slotCapacity.rawValue)),
                second: .zero ..< Index<Element>(__unchecked: (), Ordinal(
                    Index<Element>.Count(tail).subtract.saturating(slotCapacity).rawValue)
                )
            )
        }
    }
}
