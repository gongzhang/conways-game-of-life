import AppKit
import SwiftUI
import Combine
import PlaygroundSupport

let initialState = World.State(200, 200)

struct GameOfLifeView: View {
    
    @StateObject private var world: World
    @StateObject private var player: WorldPlayer
    
    init() {
        let world = World(state: initialState)
        _world = StateObject(wrappedValue: world)
        _player = StateObject(wrappedValue: WorldPlayer(world: world, step: 5))
    }
    
    private var gestureOverlay: some View {
        GeometryReader { geometry in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let x = Int(value.location.x / geometry.size.width * CGFloat(world.width))
                            let y = Int(value.location.y / geometry.size.height * CGFloat(world.height))
                            
                            world.state[x, y] = true
                        }
                        .onEnded { value in
                        }
                )
        }
    }
    
    var body: some View {
        VStack {
            WroldView(world)
                .overlay(gestureOverlay)
                .frame(width: CGFloat(world.width * 2),
                       height: CGFloat(world.height * 2))
            
            HStack {
                Button(action: { world.state = initialState }) {
                    Text("Clear")
                }
                
                Button(action: randomize) {
                    Text("Randomize")
                }
                
                Button(action: { world.quickStep(1) }) {
                    Text("Step 1")
                }
                
                Button(action: { world.quickStep(10) }) {
                    Text("Step 10")
                }
                
                Button(action: { world.quickStep(100) }) {
                    Text("Step 100")
                }
            }
            .disabled(world.isBusy || player.isPlaying)
            
            Button(action: togglePlay) {
                Text(player.isPlaying ? "Stop" : "Play")
            }
        }
    }
    
    private func randomize() {
        world.state = initialState
        let r = 25
        
        for x in (world.width / 2 - r)..<(world.width / 2 + r) {
            for y in (world.height / 2 - r)..<(world.height / 2 + r) {
                if Int.random(in: 0..<100) < 35 {
                    world.state[x, y] = true
                }
            }
        }
    }
    
    private func togglePlay() {
        if player.isPlaying {
            player.stop()
        } else {
            player.play()
        }
    }
    
}

PlaygroundPage.current.liveView = NSHostingView(rootView: GameOfLifeView())
