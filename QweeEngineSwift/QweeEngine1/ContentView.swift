import SwiftUI

struct ContentView: View {
    @StateObject private var shader = ShaderManager()
    @State private var cube: Object3D = ObjectFactory.createCube(size: 100)
    @State private var rotation: Double = 0
    @State private var lightAngle: Float = 0
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                var rotatedCube = cube
                rotatedCube.rotate(y: rotation)
                let polygons = rotatedCube.getTransformedPolygons()
 
                let sortedPolygons = polygons.sorted { $0.centerZ() > $1.centerZ() }
                
                for polygon in sortedPolygons {

                    let normal = calculateNormal(polygon.vertices)
                    let lighting = shader.calculateLighting(normal: normal)
                    let litColor = shader.applyLighting(to: polygon.color, intensity: lighting)

                    let points = polygon.vertices.map { vertex -> CGPoint in
                        let scale = 500.0 / (vertex.z + 500)
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
                        
                        context.fill(path, with: .color(litColor))
                    }
                }
            }
            .frame(width: 400, height: 400)
        }
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                rotation = 360
            }

            Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
                lightAngle += 0.01
                shader.lightDirection = (
                    x: sin(lightAngle),
                    y: 0.5,
                    z: cos(lightAngle)
                )
            }
        }
    }
}

#Preview {
    ContentView()
}
