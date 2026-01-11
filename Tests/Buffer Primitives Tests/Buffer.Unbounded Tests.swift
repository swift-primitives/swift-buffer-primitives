// Buffer.Unbounded Tests.swift
// Tests for resizable buffer storage.

import Testing
import Buffer_Primitives
import Binary_Primitives

@Suite("Buffer.Unbounded")
struct BufferUnboundedTests {

    // MARK: - Initialization

    @Suite("Initialization")
    struct Initialization {

        @Test("creates buffer with minimum capacity")
        func createsWithMinimumCapacity() throws {
            let buffer = try Buffer.Unbounded(minimumCapacity: 64, alignment: .doubleWord)

            #expect(buffer.count >= 64)
            #expect(buffer.capacity >= 64)
        }

        @Test("creates zeroed buffer")
        func createsZeroedBuffer() throws {
            let buffer = try Buffer.Unbounded.zeroed(
                minimumCapacity: 32,
                alignment: .doubleWord
            )

            buffer.withUnsafeBytes { ptr in
                for i in 0..<buffer.count {
                    #expect(ptr[i] == 0)
                }
            }
        }

        @Test("respects alignment requirement")
        func respectsAlignment() throws {
            let buffer = try Buffer.Unbounded(minimumCapacity: 100, alignment: .quadWord)

            buffer.withUnsafeBytes { ptr in
                let address = UInt(bitPattern: ptr.baseAddress!)
                #expect(address % 16 == 0)
            }
        }

        @Test("stores growth policy")
        func storesGrowthPolicy() throws {
            let buffer = try Buffer.Unbounded(
                minimumCapacity: 32,
                alignment: .doubleWord,
                growthPolicy: .exact
            )

            // Verify the policy by observing growth behavior
            var mutableBuffer = buffer
            try mutableBuffer.ensureCapacity(minimum: 100)
            #expect(mutableBuffer.capacity == 100) // exact policy
        }
    }

    // MARK: - Capacity Management

    @Suite("Capacity Management")
    struct CapacityManagement {

        @Test("ensureCapacity is no-op when sufficient")
        func ensureCapacityNoOp() throws {
            var buffer = try Buffer.Unbounded(minimumCapacity: 100, alignment: .doubleWord)
            let originalCapacity = buffer.capacity

            try buffer.ensureCapacity(minimum: 50)

            #expect(buffer.capacity == originalCapacity)
        }

        @Test("ensureCapacity grows buffer")
        func ensureCapacityGrows() throws {
            var buffer = try Buffer.Unbounded(minimumCapacity: 32, alignment: .doubleWord)

            try buffer.ensureCapacity(minimum: 256)

            #expect(buffer.capacity >= 256)
        }

        @Test("ensureCapacity preserves existing bytes")
        func ensureCapacityPreservesBytes() throws {
            var buffer = try Buffer.Unbounded.zeroed(
                minimumCapacity: 16,
                alignment: .doubleWord
            )

            // Write some test data
            buffer.withUnsafeMutableBytes { ptr in
                for i in 0..<16 {
                    ptr[i] = UInt8(i)
                }
            }

            // Grow the buffer
            try buffer.ensureCapacity(minimum: 256)

            // Verify original data preserved
            buffer.withUnsafeBytes { ptr in
                for i in 0..<16 {
                    #expect(ptr[i] == UInt8(i))
                }
            }
        }

        @Test("reserveDiscardingContents grows without preserving")
        func reserveDiscardingContentsGrows() throws {
            var buffer = try Buffer.Unbounded(minimumCapacity: 32, alignment: .doubleWord)

            try buffer.reserveDiscardingContents(minimum: 256)

            #expect(buffer.capacity >= 256)
        }

        @Test("reserveDiscardingContents is no-op when sufficient")
        func reserveDiscardingContentsNoOp() throws {
            var buffer = try Buffer.Unbounded(minimumCapacity: 100, alignment: .doubleWord)
            let originalCapacity = buffer.capacity

            try buffer.reserveDiscardingContents(minimum: 50)

            #expect(buffer.capacity == originalCapacity)
        }

        @Test("unchecked ensureCapacity works")
        func uncheckedEnsureCapacity() throws {
            var buffer = try Buffer.Unbounded(minimumCapacity: 32, alignment: .doubleWord)

            buffer.ensureCapacity(__unchecked: (), minimum: 256)

            #expect(buffer.capacity >= 256)
        }
    }

    // MARK: - Growth Policies

    @Suite("Growth Policies")
    struct GrowthPolicies {

        @Test("doubling policy doubles capacity")
        func doublingPolicy() throws {
            var buffer = try Buffer.Unbounded(
                minimumCapacity: 32,
                alignment: .doubleWord,
                growthPolicy: .doubling
            )

            let originalCapacity = buffer.capacity
            try buffer.ensureCapacity(minimum: originalCapacity + 1)

            #expect(buffer.capacity >= originalCapacity * 2)
        }

        @Test("exact policy allocates exactly required")
        func exactPolicy() throws {
            var buffer = try Buffer.Unbounded(
                minimumCapacity: 32,
                alignment: .doubleWord,
                growthPolicy: .exact
            )

            try buffer.ensureCapacity(minimum: 100)

            #expect(buffer.capacity == 100)
        }

        @Test("factor policy applies growth factor")
        func factorPolicy() throws {
            var buffer = try Buffer.Unbounded(
                minimumCapacity: 100,
                alignment: .doubleWord,
                growthPolicy: .factor(1.5)
            )

            try buffer.ensureCapacity(minimum: 101)

            #expect(buffer.capacity >= 150)
        }

        @Test("pageAligned policy rounds to page boundary")
        func pageAlignedPolicy() throws {
            var buffer = try Buffer.Unbounded(
                minimumCapacity: 100,
                alignment: .doubleWord,
                growthPolicy: .pageAligned(.page4096)
            )

            try buffer.ensureCapacity(minimum: 4097)

            #expect(buffer.capacity % 4096 == 0)
            #expect(buffer.capacity >= 8192)
        }
    }

    // MARK: - Byte Access

    @Suite("Byte Access")
    struct ByteAccess {

        @Test("withUnsafeBytes provides read access")
        func withUnsafeBytesReadAccess() throws {
            var buffer = try Buffer.Unbounded.zeroed(
                minimumCapacity: 16,
                alignment: .doubleWord
            )

            buffer.withUnsafeMutableBytes { ptr in
                ptr[0] = 0xAB
                ptr[1] = 0xCD
            }

            let result = buffer.withUnsafeBytes { ptr -> UInt8 in
                ptr[0]
            }

            #expect(result == 0xAB)
        }

        @Test("withUnsafeMutableBytes allows writing")
        func withUnsafeMutableBytesWriteAccess() throws {
            var buffer = try Buffer.Unbounded(minimumCapacity: 16, alignment: .doubleWord)

            buffer.withUnsafeMutableBytes { ptr in
                for i in 0..<16 {
                    ptr[i] = UInt8(255 - i)
                }
            }

            buffer.withUnsafeBytes { ptr in
                for i in 0..<16 {
                    #expect(ptr[i] == UInt8(255 - i))
                }
            }
        }

        @Test("bytes span has correct count")
        func bytesSpanCount() throws {
            let buffer = try Buffer.Unbounded(minimumCapacity: 64, alignment: .doubleWord)

            let span = buffer.bytes
            #expect(span.count == buffer.count)
        }

        @Test("mutableBytes span allows modification")
        func mutableBytesSpanModification() throws {
            var buffer = try Buffer.Unbounded.zeroed(
                minimumCapacity: 16,
                alignment: .doubleWord
            )

            var span = buffer.mutableBytes
            span[0] = 0xFF

            #expect(buffer.bytes[0] == 0xFF)
        }
    }

    // MARK: - Binary.Mutable Conformance

    @Suite("Binary.Mutable Conformance")
    struct BinaryMutableConformance {

        @Test("conforms to Binary.Mutable")
        func conformsToBinaryMutable() throws {
            let buffer = try Buffer.Unbounded(minimumCapacity: 32, alignment: .doubleWord)

            func acceptsMutable<T: Binary.Mutable & ~Copyable>(_ storage: borrowing T) {
                #expect(storage.count >= 0)
            }

            acceptsMutable(buffer)
        }

        @Test("Binary.Cursor works with Growable")
        func cursorWorksWithGrowable() throws {
            typealias Position = Binary.Position<Buffer.Unbounded.Scalar, Buffer.Unbounded.Space>
            typealias Offset = Binary.Offset<Buffer.Unbounded.Scalar, Buffer.Unbounded.Space>

            let buffer = try Buffer.Unbounded.zeroed(minimumCapacity: 64, alignment: .doubleWord)
            var cursor = try Binary.Cursor(storage: buffer)

            try cursor.moveWriterIndex(by: Offset(32))
            #expect(cursor.writerIndex.rawValue == 32)

            try cursor.moveReaderIndex(by: Offset(16))
            #expect(cursor.readerIndex.rawValue == 16)
            #expect(cursor.readableCount == 16)
        }

        @Test("count equals capacity")
        func countEqualsCapacity() throws {
            let buffer = try Buffer.Unbounded(minimumCapacity: 100, alignment: .doubleWord)

            #expect(buffer.count == buffer.capacity)
        }
    }

    // MARK: - Alignment Preservation

    @Suite("Alignment Preservation")
    struct AlignmentPreservation {

        @Test("alignment preserved after growth")
        func alignmentPreservedAfterGrowth() throws {
            var buffer = try Buffer.Unbounded(
                minimumCapacity: 32,
                alignment: .quadWord
            )

            try buffer.ensureCapacity(minimum: 1024)

            buffer.withUnsafeBytes { ptr in
                let address = UInt(bitPattern: ptr.baseAddress!)
                #expect(address % 16 == 0)
            }
        }

        @Test("alignment property returns correct value")
        func alignmentPropertyCorrect() throws {
            let buffer = try Buffer.Unbounded(minimumCapacity: 32, alignment: .sector512)

            #expect(buffer.alignment == .sector512)
        }
    }
}
