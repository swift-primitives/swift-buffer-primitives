//
//  File.swift
//  swift-buffer-primitives
//
//  Created by Coen ten Thije Boonkkamp on 04/02/2026.
//

import Buffer_Primitives_Core
import Storage_Primitives

extension Storage.Initialization {
    @inlinable
    public init<Element: ~Copyable>(
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
                first: header.head ..< Index<Element>(header.capacity),
                second: .zero ..< Index<Element>(
                    Index<Element>.Count(tail).subtract.saturating(header.capacity)
                )
            )
        }
    }
}

extension Storage.Initialization {
    @inlinable
    public init<Element: ~Copyable, let capacity: Int>(
        _ header: Buffer<Element>.Ring.Header.Cyclic<capacity>
    ) {
        if header.count == .zero {
            self = .empty
            return
        }

        let slotCapacity = Buffer<Element>.Ring.Header.Cyclic<capacity>.slotCapacity
        let headIndex = Index<Element>(Ordinal(header.head.rawValue))
        let tail = headIndex + header.count

        if tail <= slotCapacity {
            self = .one(headIndex ..< tail)
        } else {
            self = .two(
                first: headIndex ..< Index<Element>(slotCapacity),
                second: .zero ..< Index<Element>(
                    Index<Element>.Count(tail).subtract.saturating(slotCapacity)
                )
            )
        }
    }
}
