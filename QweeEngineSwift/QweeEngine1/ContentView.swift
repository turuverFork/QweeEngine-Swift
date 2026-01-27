import SwiftUI

struct ContentView: View {
    @StateObject private var physicsWorld = PhysicsWorld()
    @StateObject private var inputManager = InputManager()
    @State private var cubes: [Object3D] = []
    @State private var physicsBodies: [PhysicsBody] = []
    @State private var cameraOffset: Float = 15.0
    @State private var isAddingCubes = false
    @State private var physicsEnabled = true
    
    let cubeSize: Float = 2.0
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                for (index, body) in physicsBodies.enumerated() {
                    if index < cubes.count {
                        var cube = cubes[index]
                        cube.position = Vertex3D(
                            x: CGFloat(body.position.x),
                            y: CGFloat(body.position.y),
                            z: CGFloat(body.position.z)
                        )

                        let polygons = cube.getTransformedPolygons()
                        let sortedPolygons = polygons.sorted { $0.centerZ() > $1.centerZ() }
                        
                        for polygon in sortedPolygons {
                            let points = polygon.vertices.map { vertex -> CGPoint in
                                let cameraZ = vertex.z + CGFloat(cameraOffset)
                                let scale = 300.0 / max(cameraZ, 1.0)
                                return CGPoint(
                                    x: vertex.x * scale + center.x,
                                    y: vertex.y * scale + center.y
                                )
                            }
                            
                            if points.count >= 3 {
                                var path = Path()
                                path.move(to: points[0])
                                for i in 1..<points.count {
                                    path.addLine(to: points[i])
                                }
                                path.closeSubpath()
                                
                                context.fill(path, with: .color(polygon.color))
                                context.stroke(path, with: .color(.white.opacity(0.3)), lineWidth: 1)
                            }
                        }
                    }
                }
            }
            .frame(width: 600, height: 500)

            VStack {
                HStack {
                    PhysicsDebugView(world: physicsWorld)
                        .frame(width: 250)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 10) {
                        Text("PHYSICS DEMO")
                            .font(.title)
                            .foregroundColor(.yellow)
                        
                        Text("Cube Count: \(cubes.count)")
                            .foregroundColor(.white)
                        
                        Text("Camera: \(String(format: "%.1f", cameraOffset))")
                            .foregroundColor(.white)
                        
                        Toggle("Physics Enabled", isOn: $physicsEnabled)
                            .foregroundColor(.white)
                            .onChange(of: physicsEnabled) { newValue in
                                physicsWorld.enabled = newValue
                            }
                        
                        HStack {
                            Button(action: addCube) {
                                Label("Add Cube", systemImage: "cube.fill")
                                    .frame(width: 120)
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button(action: addSphere) {
                                Label("Add Sphere", systemImage: "circle.fill")
                                    .frame(width: 120)
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button(action: resetScene) {
                                Label("Reset", systemImage: "trash")
                                    .frame(width: 120)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                        
                        Button(action: toggleCubeRain) {
                            Label(isAddingCubes ? "Stop Rain" : "Start Rain",
                                  systemImage: isAddingCubes ? "cloud.rain.fill" : "cloud.sun.fill")
                                .frame(width: 200)
                        }
                        .buttonStyle(.bordered)
                        .tint(isAddingCubes ? .red : .green)
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                }
                .padding()
                
                Spacer()

                VStack(alignment: .leading, spacing: 5) {
                    Text("CONTROLS:")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    
                    Text("Click: Add cube at cursor")
                    Text("Space: Add random force")
                    Text("R: Reset scene")
                    Text("Scroll: Zoom camera")
                    Text("Arrow Keys: Move camera")
                }
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
                .padding()
                .background(Color.black.opacity(0.5))
                .cornerRadius(8)
                .padding(.bottom)
            }
        }
        .onAppear {
            setupPhysics()
            startGameLoop()
        }
    }
    
    private func setupPhysics() {
        physicsWorld.enabled = true
        physicsWorld.gravity = [0, -9.81, 0]

        let floor = PhysicsBody(
            shape: .box(size: [50, 1, 50]),
            bodyType: .static,
            material: PhysicsMaterial(friction: 0.8, restitution: 0.1)
        )
        floor.position = [0, -10, 0]
        physicsWorld.addBody(floor)
        physicsBodies.append(floor)

        for _ in 0..<3 {
            addRandomCube()
        }
    }
    
    private func startGameLoop() {
        Timer.scheduledTimer(withTimeInterval: 1/60.0, repeats: true) { _ in
            let deltaTime: Float = 1/60.0

            inputManager.update()

            physicsWorld.update(deltaTime: deltaTime)

            handleInput(deltaTime: deltaTime)
  
            if isAddingCubes {
                addRandomCube()
            }
        }
    }
    
    private func handleInput(deltaTime: Float) {
        let cameraSpeed: Float = 10.0
        
        if inputManager.inputState.isKeyPressed(.up) {
            cameraOffset = Swift.max(5.0, cameraOffset - cameraSpeed * deltaTime)
        }
        if inputManager.inputState.isKeyPressed(.down) {
            cameraOffset = Swift.min(50.0, cameraOffset + cameraSpeed * deltaTime)
        }

        cameraOffset += Float(inputManager.inputState.scrollDelta) * 0.5
        cameraOffset = Swift.max(5.0, Swift.min(50.0, cameraOffset))

        if inputManager.inputState.mouseDown {
            addCubeAtMouse()
        }

        if inputManager.inputState.isKeyPressed(.space) {
            applyRandomForces()
        }

        if inputManager.inputState.isKeyPressed(.r) {
            resetScene()
        }
    }
    
    private func addCube() {
        addRandomCube()
    }
    
    private func addSphere() {
        let sphereBody = PhysicsBody(
            shape: .sphere(radius: cubeSize / 2),
            bodyType: .dynamic,
            material: PhysicsMaterial(density: 1.0, friction: 0.3, restitution: 0.7)
        )
        
        sphereBody.position = [
            Float.random(in: -5...5),
            Float.random(in: 5...15),
            Float.random(in: -5...5)
        ]

        sphereBody.applyImpulse([
            Float.random(in: -3...3),
            Float.random(in: 0...5),
            Float.random(in: -3...3)
        ])
        
        physicsWorld.addBody(sphereBody)
        physicsBodies.append(sphereBody)

        let cube = ObjectFactory.createCube(size: CGFloat(cubeSize))
        cubes.append(cube)
    }
    
    private func addRandomCube() {
        let cubeBody = PhysicsBody(
            shape: .box(size: [cubeSize, cubeSize, cubeSize]),
            bodyType: .dynamic,
            material: PhysicsMaterial(density: 2.0, friction: 0.5, restitution: 0.3)
        )
        
        cubeBody.position = [
            Float.random(in: -5...5),
            Float.random(in: 5...15),
            Float.random(in: -5...5)
        ]

        cubeBody.applyImpulse([
            Float.random(in: -2...2),
            Float.random(in: 0...3),
            Float.random(in: -2...2)
        ])
        
        physicsWorld.addBody(cubeBody)
        physicsBodies.append(cubeBody)

        let cube = ObjectFactory.createCube(size: CGFloat(cubeSize))
        cubes.append(cube)
    }
    
    private func addCubeAtMouse() {
        addRandomCube()
    }
    
    private func applyRandomForces() {
        for body in physicsBodies where body.bodyType == .dynamic {
            let randomForce = SIMD3<Float>(
                Float.random(in: -10...10),
                Float.random(in: 0...20),
                Float.random(in: -10...10)
            )
            body.applyForce(randomForce)
        }
    }
    
    private func toggleCubeRain() {
        isAddingCubes.toggle()
    }
    
    private func resetScene() {

        let floor = physicsBodies.first { $0.bodyType == .static }
        
        physicsWorld.bodies.removeAll()
        physicsBodies.removeAll()
        cubes.removeAll()
        
        if let floor = floor {
            physicsWorld.addBody(floor)
            physicsBodies.append(floor)
        }

        for _ in 0..<3 {
            addRandomCube()
        }
        
        isAddingCubes = false
        cameraOffset = 15.0
    }
}

#Preview {
    ContentView()
}
