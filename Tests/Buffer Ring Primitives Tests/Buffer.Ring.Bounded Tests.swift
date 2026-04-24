import Testing
import Buffer_Ring_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Ring.Bounded")
struct RingBoundedTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
}

// MARK: - Unit

extension RingBoundedTests.Unit {

    @Test
    func `full rejection — pushBack returns element when full`() {
        var buffer = Buffer<Int>.Ring.Bounded(minimumCapacity: 2)
        let cap = buffer.capacity.rawValue.rawValue

        // Fill to capacity
        var i: UInt = 0
        while i < cap {
            let rejected = buffer.push.back(Int(i))
            #expect(rejected == nil)
            i += 1
        }
        #expect(buffer.isFull)

        // Next push is rejected
        let rejected = buffer.push.back(999)
        #expect(rejected == 999)
    }

    @Test
    func `full rejection — pushFront returns element when full`() {
        var buffer = Buffer<Int>.Ring.Bounded(minimumCapacity: 2)
        let cap = buffer.capacity.rawValue.rawValue

        var i: UInt = 0
        while i < cap {
            _ = buffer.push.back(Int(i))
            i += 1
        }

        let rejected = buffer.push.front(999)
        #expect(rejected == 999)
    }

    @Test
    func `peekFront and peekBack (Copyable)`() throws {
        let buffer = try Buffer<Int>.Ring.Bounded([10, 20, 30], capacity: 4)
        #expect(buffer.peek.front == 10)
        #expect(buffer.peek.back == 30)
        #expect(buffer.count == 3)
    }

    @Test
    func `removeAll clears buffer`() throws {
        var buffer = try Buffer<Int>.Ring.Bounded([1, 2, 3], capacity: 4)
        buffer.remove.all()
        #expect(buffer.isEmpty)
    }

    @Test
    func `Sequence.Protocol iteration (Copyable)`() throws {
        let buffer = try Buffer<Int>.Ring.Bounded([10, 20, 30], capacity: 4)
        var collected: [Int] = []
        var iter = buffer.makeIterator()
        while let value = iter.next() {
            collected.append(value)
        }
        #expect(collected == [10, 20, 30])
    }

    @Test
    func `checkpoint and restore`() throws {
        var buffer = try Buffer<Int>.Ring.Bounded([10, 20], capacity: 8)
        let cp = buffer.checkpoint
        _ = buffer.push.back(30)
        _ = buffer.push.back(40)

        buffer.restore(to: cp)
        #expect(buffer.count == 2)
        #expect(buffer.pop.front() == 10)
        #expect(buffer.pop.front() == 20)
    }
}

// MARK: - Edge Cases

extension RingBoundedTests.EdgeCase {

    @Test
    func `capacity-of-1 ring`() {
        var buffer = Buffer<Int>.Ring.Bounded(minimumCapacity: 1)
        let rejected = buffer.push.back(42)
        #expect(rejected == nil)
        #expect(buffer.isFull)

        let value = buffer.pop.front()
        #expect(value == 42)
        #expect(buffer.isEmpty)
    }

    @Test
    func `full buffer pushFront evicts nothing — returns element`() {
        var buffer = Buffer<Int>.Ring.Bounded(minimumCapacity: 2)
        let cap = buffer.capacity.rawValue.rawValue
        var i: UInt = 0
        while i < cap {
            _ = buffer.push.back(Int(i))
            i += 1
        }

        let rejected = buffer.push.front(999)
        #expect(rejected == 999)
        // Original elements untouched
        #expect(buffer.peek.front == 0)
    }

    @Test
    func `restore after wrapping`() {
        var buffer = Buffer<Int>.Ring.Bounded(minimumCapacity: 4)
        _ = buffer.push.back(1)
        _ = buffer.push.back(2)
        _ = buffer.push.back(3)
        _ = buffer.pop.front()
        _ = buffer.pop.front()
        let cp = buffer.checkpoint
        _ = buffer.push.back(4)
        _ = buffer.push.back(5)

        buffer.restore(to: cp)
        #expect(buffer.count == 1)
        #expect(buffer.pop.front() == 3)
    }
}

// MARK: - Integration

extension RingBoundedTests.Integration {

    @Test
    func `interleaved push/pop cycles`() {
        var buffer = Buffer<Int>.Ring.Bounded(minimumCapacity: 3)
        _ = buffer.push.back(1)
        _ = buffer.push.back(2)
        #expect(buffer.pop.front() == 1)
        _ = buffer.push.back(3)
        #expect(buffer.pop.front() == 2)
        _ = buffer.push.back(4)
        #expect(buffer.pop.front() == 3)
        #expect(buffer.pop.front() == 4)
        #expect(buffer.isEmpty)
    }

    @Test
    func `fill/drain cycle`() {
        var buffer = Buffer<Int>.Ring.Bounded(minimumCapacity: 4)
        let cap = Int(buffer.capacity.rawValue.rawValue)

        // Fill
        var i = 0
        while i < cap {
            _ = buffer.push.back(i)
            i += 1
        }
        #expect(buffer.isFull)

        // Drain
        var drained: [Int] = []
        buffer.drain { drained.append($0) }
        #expect(buffer.isEmpty)
        #expect(drained.count == cap)
    }
}

// MARK: - Release-mode regression guard (Finding #12 narrow-shape watchflag)
//
// Permanent positive-assertion regression guard for the V11 narrow-shape
// compiler bug documented at swift-institute/Audits/borrow-pointer-
// storage-release-miscompile.md finding #12, archived at the experiment
// swift-institute/Experiments/borrow-pointer-storage-release-miscompile
// V10/V11 (commit cee7a7a).
//
// Buffer.Ring.Bounded is one of ~16 swift-buffer-primitives consumers
// of Memory.Inline.pointer(at:). Memory.Inline's production shape
// (`@_rawLayout`-backed `_storage`) is empirically safe in release
// despite the V11 experiment showing a narrower shape (plain stored
// ~Copyable field, non-generic) fails. This test asserts the
// consumer-side safety holds — if a future refactor of either
// Memory.Inline or Buffer.Ring.Bounded migrates toward the V11 shape,
// or an optimizer regression breaks the `@_rawLayout` discriminator,
// the positive assertions flip to failing and the regression is caught
// before it ships.

extension RingBoundedTests.Unit {
    @Test
    func `peek front and back return stable values across repeated reads (finding #12 regression guard)`() {
        var buffer = Buffer<Int>.Ring.Bounded(minimumCapacity: 4)
        _ = buffer.push.back(10)
        _ = buffer.push.back(20)
        _ = buffer.push.back(30)

        let front1 = buffer.peek.front
        let front2 = buffer.peek.front
        let back1 = buffer.peek.back
        let back2 = buffer.peek.back

        #expect(front1 == 10)
        #expect(front2 == 10)
        #expect(back1 == 30)
        #expect(back2 == 30)
    }
}
