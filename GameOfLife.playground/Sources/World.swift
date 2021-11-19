import Foundation
import SwiftUI
import Combine

infix operator %%: MultiplicationPrecedence

/// https://forums.swift.org/t/modulo-operation-in-swift/7018
public func %%<T: BinaryInteger>(lhs: T, rhs: T) -> T {
   let rem = lhs % rhs // -rhs <= rem <= rhs
   return rem >= 0 ? rem : rem + rhs
}

public class World: ObservableObject {
    
    public struct State {
        let width: Int
        let height: Int
        
        private var buffer: [Bool]
        private var neighbors: [Int]
        
        public init(_ w: Int, _ h: Int) {
            width = w
            height = h
            buffer = Array(repeating: false, count: w * h)
            neighbors = Array(repeating: 0, count: w * h)
        }
        
        public subscript(_ x: Int, _ y: Int) -> Bool {
            get {
                buffer[y * width + x]
            }
            set {
                let i = y * width + x
                guard buffer[i] != newValue else {
                    return
                }
                
                buffer[i] = newValue
                let delta = newValue ? +1 : -1
                
                adjustNeighbors(x - 1, y - 1, delta: delta)
                adjustNeighbors(x    , y - 1, delta: delta)
                adjustNeighbors(x + 1, y - 1, delta: delta)
                
                adjustNeighbors(x - 1, y, delta: delta)
                adjustNeighbors(x + 1, y, delta: delta)
                
                adjustNeighbors(x - 1, y + 1, delta: delta)
                adjustNeighbors(x    , y + 1, delta: delta)
                adjustNeighbors(x + 1, y + 1, delta: delta)
            }
        }
        
        private mutating func adjustNeighbors(_ x: Int, _ y: Int, delta: Int) {
            let x = x %% width
            let y = y %% height
            neighbors[y * width + x] += delta
        }
        
        func next() -> State {
            var next = State(width, height)
            for x in 0..<width {
                var livingIndices: [Int] = []
                
                for y in 0..<height {
                    if self[x, y] {
                        // 当前细胞为存活状态时
                        switch neighbors[y * width + x] {
                        case 0..<2:
                            // 当周围的存活细胞低于2个时（不包含2个），该细胞变成死亡状态。（模拟生命数量稀少）
                            break
                            
                        case 2...3:
                            // 当周围有2个或3个存活细胞时，该细胞保持原样。
                            livingIndices.append(y)
                            
                        default:
                            // 当周围有超过3个存活细胞时，该细胞变成死亡状态。（模拟生命数量过多）
                            break
                        }
                        
                    } else {
                        // 当前细胞为死亡状态时，当周围有3个存活细胞时，该细胞变成存活状态。（模拟繁殖）
                        if neighbors[y * width + x] == 3 {
                            livingIndices.append(y)
                        }
                    }
                }
                
                for y in livingIndices {
                    next[x, y] = true
                }
            }
            return next
        }
        
        func asyncNext() -> Future<State, Never> {
            Future { promise in
                DispatchQueue.global(qos: .userInteractive).async {
                    var next = State(width, height)
                    let queue = DispatchQueue(label: "World.State.asyncNext.queue", qos: .userInteractive)
                    
                    DispatchQueue.concurrentPerform(iterations: height) { y in
                        var livingIndices: [Int] = []
                        let yOffset = y * width
                        
                        for x in 0..<width {
                            if self[x, y] {
                                // 当前细胞为存活状态时
                                switch neighbors[yOffset + x] {
                                case 0..<2:
                                    // 当周围的存活细胞低于2个时（不包含2个），该细胞变成死亡状态。（模拟生命数量稀少）
                                    break
                                    
                                case 2...3:
                                    // 当周围有2个或3个存活细胞时，该细胞保持原样。
                                    livingIndices.append(x)
                                    
                                default:
                                    // 当周围有超过3个存活细胞时，该细胞变成死亡状态。（模拟生命数量过多）
                                    break
                                }
                                
                            } else {
                                // 当前细胞为死亡状态时，当周围有3个存活细胞时，该细胞变成存活状态。（模拟繁殖）
                                if neighbors[yOffset + x] == 3 {
                                    livingIndices.append(x)
                                }
                            }
                        }
                        
                        queue.sync {
                            for x in livingIndices {
                                next[x, y] = true
                            }
                        }
                    }
                    
                    promise(.success(next))
                }
            }
        }
    }
    
    @Published public var state: State
    @Published public private(set) var isBusy = false
    
    public var width: Int { state.width }
    public var height: Int { state.height }
    
    public init(state: State) {
        self.state = state
    }
    
    public func toggle(_ x: Int, _ y: Int) {
        state[x, y] = !state[x, y]
    }
    
    public func step() {
        state = state.next()
    }
    
    public func step(_ count: Int) {
        for _ in 0..<count {
            step()
        }
    }
    
    public func quickStep(_ count: Int, completion: @escaping () -> () = {}) {
        isBusy = true
        var future = state.asyncNext().eraseToAnyPublisher()
        for _ in 1..<count {
            future = future.map { next in
                next.asyncNext()
            }
            .switchToLatest()
            .eraseToAnyPublisher()
        }
        
        future.receive(on: DispatchQueue.main).subscribe(Subscribers.Sink(receiveCompletion: { _ in
            
        }, receiveValue: { next in
            self.state = next
            self.isBusy = false
            completion()
        }))
    }
    
    
}

public struct WroldView: View {
    
    @ObservedObject var world: World
    
    public init(_ world: World) {
        self._world = ObservedObject(initialValue: world)
    }
    
    public var body: some View {
        Canvas { (ctx: inout GraphicsContext, size: CGSize) in
            ctx.fill(Path { path in
                path.addRect(CGRect(origin: .zero, size: size))
            }, with: .color(.white))
            
            ctx.fill(Path { path in
                let xratio = size.width / CGFloat(world.width)
                let yratio = size.height / CGFloat(world.height)
                
                for x in 0..<world.width {
                    for y in 0..<world.height {
                        if world.state[x, y] {
                            let center = CGPoint(x: CGFloat(x) * xratio, y: CGFloat(y) * yratio)
                            path.addRect(CGRect(origin: center, size: CGSize(width: xratio, height: yratio)))
                        }
                    }
                }
            }, with: .color(.black))
        }
    }
    
}

public class WorldPlayer: ObservableObject {
    
    @Published public private(set) var isPlaying = false
    
    private let world: World
    private let step: Int
    
    public init(world: World, step: Int) {
        self.world = world
        self.step = step
    }
    
    public func play() {
        guard isPlaying == false else { return }
        isPlaying = true
        task()
    }
    
    private func task() {
        world.quickStep(step) { [weak self] in
            guard let self = self else { return }
            guard self.isPlaying else { return }
            self.task()
        }
    }
    
    public func stop() {
        guard isPlaying else { return }
        isPlaying = false
    }
    
}
