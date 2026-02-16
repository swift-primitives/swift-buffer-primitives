import Testing
import Buffer_Linear_Inline_Primitives
import Buffer_Primitives_Test_Support

@Suite("Buffer.Linear.Small")
struct LinearSmallTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
}

// MARK: - Unit

extension LinearSmallTests.Unit {

    @Test
    func `init creates inline storage`() {
        let buffer = Buffer<Int>.Linear.Small<4>()
        #expect(buffer.isEmpty == true)
        #expect(buffer.count == .zero)
        #expect(buffer.isSpilled == false)
    }

    @Test
    func `append within inline capacity stays inline`() {
        var buffer = Buffer<Int>.Linear.Small<4>()
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)

        #expect(buffer.count == 3)
        #expect(buffer.isSpilled == false)
    }

    @Test
    func `append beyond inline capacity triggers spill`() {
        var buffer = Buffer<Int>.Linear.Small<2>()
        buffer.append(10)
        buffer.append(20)
        #expect(buffer.isSpilled == false)

        buffer.append(30)
        #expect(buffer.isSpilled == true)
        #expect(buffer.count == 3)
    }

    @Test
    func `append and removeFirst in inline mode`() {
        var buffer = Buffer<Int>.Linear.Small<4>()
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)

        #expect(buffer.removeFirst() == 10)
        #expect(buffer.removeFirst() == 20)
        #expect(buffer.removeFirst() == 30)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `append and removeFirst in heap mode`() {
        var buffer = Buffer<Int>.Linear.Small<2>()
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)
        #expect(buffer.isSpilled == true)

        #expect(buffer.removeFirst() == 10)
        #expect(buffer.removeFirst() == 20)
        #expect(buffer.removeFirst() == 30)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `append and removeLast in inline mode`() {
        var buffer = Buffer<Int>.Linear.Small<4>()
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)

        #expect(buffer.removeLast() == 30)
        #expect(buffer.removeLast() == 20)
        #expect(buffer.removeLast() == 10)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `append and removeLast in heap mode`() {
        var buffer = Buffer<Int>.Linear.Small<2>()
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)
        #expect(buffer.isSpilled == true)

        #expect(buffer.removeLast() == 30)
        #expect(buffer.removeLast() == 20)
        #expect(buffer.removeLast() == 10)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `remove at in inline mode`() {
        var buffer = Buffer<Int>.Linear.Small<4>()
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)

        #expect(buffer.remove(at: 1) == 20)
        #expect(buffer.count == 2)
        #expect(buffer[0] == 10)
        #expect(buffer[1] == 30)
    }

    @Test
    func `remove at in heap mode`() {
        var buffer = Buffer<Int>.Linear.Small<2>()
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)
        #expect(buffer.isSpilled == true)

        #expect(buffer.remove(at: 1) == 20)
        #expect(buffer.count == 2)
        #expect(buffer[0] == 10)
        #expect(buffer[1] == 30)
    }

    @Test
    func `removeAll resets to inline mode`() {
        var buffer = Buffer<Int>.Linear.Small<2>()
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)
        #expect(buffer.isSpilled == true)

        buffer.removeAll()
        #expect(buffer.isEmpty == true)
        #expect(buffer.isSpilled == false)
    }

    @Test
    func `removeAll keepingCapacity true stays in heap mode`() {
        var buffer = Buffer<Int>.Linear.Small<2>()
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)
        #expect(buffer.isSpilled == true)

        buffer.removeAll(keepingCapacity: true)
        #expect(buffer.isEmpty == true)
        #expect(buffer.isSpilled == true)
    }

    @Test
    func `peekFront and peekBack inline`() {
        var buffer = Buffer<Int>.Linear.Small<4>()
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)

        #expect(buffer.peekFront == 10)
        #expect(buffer.peekBack == 30)
    }

    @Test
    func `peekFront and peekBack heap`() {
        var buffer = Buffer<Int>.Linear.Small<2>()
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)
        #expect(buffer.isSpilled == true)

        #expect(buffer.peekFront == 10)
        #expect(buffer.peekBack == 30)
    }

    @Test
    func `subscript read in inline mode`() {
        var buffer = Buffer<Int>.Linear.Small<4>()
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)

        #expect(buffer[0] == 10)
        #expect(buffer[1] == 20)
        #expect(buffer[2] == 30)
    }

    @Test
    func `subscript read in heap mode`() {
        var buffer = Buffer<Int>.Linear.Small<2>()
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)
        #expect(buffer.isSpilled == true)

        #expect(buffer[0] == 10)
        #expect(buffer[1] == 20)
        #expect(buffer[2] == 30)
    }

    @Test
    func `subscript modify in inline mode`() {
        var buffer = Buffer<Int>.Linear.Small<4>()
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)

        buffer[1] = 999
        #expect(buffer[1] == 999)
    }

    @Test
    func `subscript modify in heap mode`() {
        var buffer = Buffer<Int>.Linear.Small<2>()
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)
        #expect(buffer.isSpilled == true)

        buffer[1] = 999
        #expect(buffer[1] == 999)
    }

    @Test
    func `drain in inline mode`() {
        var buffer = Buffer<Int>.Linear.Small<4>()
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)

        var drained: [Int] = []
        buffer.drain { drained.append($0) }
        #expect(drained == [10, 20, 30])
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `drain in heap mode`() {
        var buffer = Buffer<Int>.Linear.Small<2>()
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)
        #expect(buffer.isSpilled == true)

        var drained: [Int] = []
        buffer.drain { drained.append($0) }
        #expect(drained == [10, 20, 30])
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `Sequence.Protocol iteration in inline mode`() {
        var buffer = Buffer<Int>.Linear.Small<4>()
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)

        var collected: [Int] = []
        var iter = buffer.makeIterator()
        while let value = iter.next() {
            collected.append(value)
        }
        #expect(collected == [10, 20, 30])
    }

    @Test
    func `Sequence.Protocol iteration in heap mode`() {
        var buffer = Buffer<Int>.Linear.Small<2>()
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)
        #expect(buffer.isSpilled == true)

        var collected: [Int] = []
        var iter = buffer.makeIterator()
        while let value = iter.next() {
            collected.append(value)
        }
        #expect(collected == [10, 20, 30])
    }

    @Test
    func `single element inline`() {
        var buffer = Buffer<Int>.Linear.Small<1>()
        buffer.append(42)
        #expect(buffer.count == 1)
        #expect(buffer.isSpilled == false)
        #expect(buffer.removeLast() == 42)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `isSpilled false initially`() {
        let buffer = Buffer<Int>.Linear.Small<8>()
        #expect(buffer.isSpilled == false)
    }

    @Test
    func `isSpilled true after growth`() {
        var buffer = Buffer<Int>.Linear.Small<2>()
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        #expect(buffer.isSpilled == true)
    }

    @Test
    func `reserveCapacity beyond inline triggers spill`() {
        var buffer = Buffer<Int>.Linear.Small<4>()
        buffer.append(1)
        buffer.reserveCapacity(100)
        #expect(buffer.isSpilled == true)
        #expect(buffer.capacity >= 100)
        #expect(buffer[0] == 1)
    }

    @Test
    func `elements survive spill`() {
        var buffer = Buffer<Int>.Linear.Small<3>()
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)
        #expect(buffer.isSpilled == false)

        // Trigger spill
        buffer.append(40)
        #expect(buffer.isSpilled == true)

        // Verify all elements survived
        #expect(buffer[0] == 10)
        #expect(buffer[1] == 20)
        #expect(buffer[2] == 30)
        #expect(buffer[3] == 40)
    }

    @Test
    func `isFull in inline mode`() {
        var buffer = Buffer<Int>.Linear.Small<2>()
        #expect(buffer.isFull == false)
        buffer.append(1)
        #expect(buffer.isFull == false)
        buffer.append(2)
        #expect(buffer.isFull == true)
    }

    @Test
    func `isFull after spill is always false`() {
        var buffer = Buffer<Int>.Linear.Small<2>()
        buffer.append(1)
        buffer.append(2)
        buffer.append(3) // triggers spill
        #expect(buffer.isSpilled == true)
        #expect(buffer.isFull == false)
    }

    @Test
    func `capacity reflects mode`() {
        var buffer = Buffer<Int>.Linear.Small<4>()
        #expect(buffer.capacity == 4)

        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        buffer.append(4)
        buffer.append(5) // triggers spill
        #expect(buffer.isSpilled == true)
        #expect(buffer.capacity >= 8)
    }
}

// MARK: - Edge Cases

extension LinearSmallTests.EdgeCase {

    @Test
    func `removeAll keepingCapacity false resets to inline`() {
        var buffer = Buffer<Int>.Linear.Small<2>()
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)
        #expect(buffer.isSpilled == true)

        buffer.removeAll(keepingCapacity: false)
        #expect(buffer.isEmpty == true)
        #expect(buffer.isSpilled == false)
    }

    @Test
    func `reserveCapacity within inline does not spill`() {
        var buffer = Buffer<Int>.Linear.Small<8>()
        buffer.append(1)
        buffer.reserveCapacity(4)
        #expect(buffer.isSpilled == false)
    }
}

// MARK: - Integration

extension LinearSmallTests.Integration {

    @Test
    func `model test — random ops match Array model`() {
        var buffer = Buffer<Int>.Linear.Small<4>()
        var model: [Int] = []

        // Append a bunch
        for i in 0..<20 {
            buffer.append(i)
            model.append(i)
        }
        #expect(buffer.isSpilled == true)

        // Check all elements match via typed iteration
        var slot: Index<Int> = .zero
        let end = buffer.count.map(Ordinal.init)
        var modelIdx = 0
        while slot < end {
            #expect(buffer[slot] == model[modelIdx])
            slot += .one
            modelIdx += 1
        }

        // Remove some from back
        for _ in 0..<5 {
            let bufElement = buffer.removeLast()
            let modelElement = model.removeLast()
            #expect(bufElement == modelElement)
        }

        // Remove some from front
        for _ in 0..<3 {
            let bufElement = buffer.removeFirst()
            let modelElement = model.removeFirst()
            #expect(bufElement == modelElement)
        }

        // Check remaining elements match
        slot = .zero
        let remainingEnd = buffer.count.map(Ordinal.init)
        modelIdx = 0
        while slot < remainingEnd {
            #expect(buffer[slot] == model[modelIdx])
            slot += .one
            modelIdx += 1
        }
        #expect(buffer.count == Index<Int>.Count(UInt(model.count)))
    }
}
