
import SwiftUI

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct Quad: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        
        // Второй треугольник
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        
        return path
    }
}

struct Polygon: Shape {
    let sides: Int
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let radius = min(rect.width, rect.height) / 2
        
        guard sides >= 3 else { return path }
        
        for i in 0..<sides {
            let angle = (2 * .pi * CGFloat(i) / CGFloat(sides)) - (.pi / 2)
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        
        path.closeSubpath()
        return path
    }
}

struct Vertex3D: Equatable {
    let x, y, z: CGFloat
    
    func rotated(aroundX angleX: CGFloat, aroundY angleY: CGFloat, aroundZ angleZ: CGFloat) -> Vertex3D {
        let radX = angleX * .pi / 180
        let radY = angleY * .pi / 180
        let radZ = angleZ * .pi / 180

        var y1 = y * cos(radX) - z * sin(radX)
        var z1 = y * sin(radX) + z * cos(radX)

        let x2 = x * cos(radY) + z1 * sin(radY)
        z1 = -x * sin(radY) + z1 * cos(radY)

        let x3 = x2 * cos(radZ) - y1 * sin(radZ)
        y1 = x2 * sin(radZ) + y1 * cos(radZ)
        
        return Vertex3D(x: x3, y: y1, z: z1)
    }
    
    func projected(perspective: CGFloat = 500) -> CGPoint {
        let scale = perspective / (z + perspective)
        return CGPoint(x: x * scale, y: y * scale)
    }
}

struct Polygon3D: Identifiable {
    let id = UUID()
    let vertices: [Vertex3D]
    let color: Color
    var opacity: Double = 1.0
    
    func rotated(aroundX angleX: CGFloat, aroundY angleY: CGFloat, aroundZ angleZ: CGFloat) -> Polygon3D {
        let rotatedVertices = vertices.map { $0.rotated(aroundX: angleX, aroundY: angleY, aroundZ: angleZ) }
        return Polygon3D(vertices: rotatedVertices, color: color, opacity: opacity)
    }
    
    func projected(perspective: CGFloat = 500) -> [CGPoint] {
        return vertices.map { $0.projected(perspective: perspective) }
    }
    
    func centerZ() -> CGFloat {
        return vertices.reduce(0) { $0 + $1.z } / CGFloat(vertices.count)
    }
}

struct Object3D {
    var polygons: [Polygon3D]
    var position: Vertex3D = Vertex3D(x: 0, y: 0, z: 0)
    var rotation: (x: CGFloat, y: CGFloat, z: CGFloat) = (0, 0, 0)
    var scale: CGFloat = 1.0
    
    mutating func rotate(x: CGFloat = 0, y: CGFloat = 0, z: CGFloat = 0) {
        rotation.x += x
        rotation.y += y
        rotation.z += z
    }
    
    mutating func move(x: CGFloat = 0, y: CGFloat = 0, z: CGFloat = 0) {
        position = Vertex3D(
            x: position.x + x,
            y: position.y + y,
            z: position.z + z
        )
    }
    
    func getTransformedPolygons() -> [Polygon3D] {
        polygons.map { polygon in

            let scaledVertices = polygon.vertices.map { vertex in
                Vertex3D(
                    x: vertex.x * scale,
                    y: vertex.y * scale,
                    z: vertex.z * scale
                )
            }

            let rotatedPolygon = Polygon3D(
                vertices: scaledVertices,
                color: polygon.color,
                opacity: polygon.opacity
            ).rotated(aroundX: rotation.x, aroundY: rotation.y, aroundZ: rotation.z)
  
            let positionedVertices = rotatedPolygon.vertices.map { vertex in
                Vertex3D(
                    x: vertex.x + position.x,
                    y: vertex.y + position.y,
                    z: vertex.z + position.z
                )
            }
            
            return Polygon3D(
                vertices: positionedVertices,
                color: rotatedPolygon.color,
                opacity: rotatedPolygon.opacity
            )
        }
    }
}

struct ObjectFactory {

    static func createCube(size: CGFloat = 100, color: Color = .red) -> Object3D {
        let s = size / 2
        let vertices = [

            [Vertex3D(x: -s, y: -s, z: s), Vertex3D(x: s, y: -s, z: s), Vertex3D(x: s, y: s, z: s), Vertex3D(x: -s, y: s, z: s)],

            [Vertex3D(x: -s, y: -s, z: -s), Vertex3D(x: -s, y: s, z: -s), Vertex3D(x: s, y: s, z: -s), Vertex3D(x: s, y: -s, z: -s)],

            [Vertex3D(x: -s, y: -s, z: -s), Vertex3D(x: s, y: -s, z: -s), Vertex3D(x: s, y: -s, z: s), Vertex3D(x: -s, y: -s, z: s)],

            [Vertex3D(x: -s, y: s, z: -s), Vertex3D(x: -s, y: s, z: s), Vertex3D(x: s, y: s, z: s), Vertex3D(x: s, y: s, z: -s)],

            [Vertex3D(x: -s, y: -s, z: -s), Vertex3D(x: -s, y: -s, z: s), Vertex3D(x: -s, y: s, z: s), Vertex3D(x: -s, y: s, z: -s)],

            [Vertex3D(x: s, y: -s, z: -s), Vertex3D(x: s, y: s, z: -s), Vertex3D(x: s, y: s, z: s), Vertex3D(x: s, y: -s, z: s)]
        ]
        
        let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple]
        
        let polygons = vertices.enumerated().map { index, vertexArray in

            let triangle1 = [vertexArray[0], vertexArray[1], vertexArray[2]]
            let triangle2 = [vertexArray[0], vertexArray[2], vertexArray[3]]
            
            return [
                Polygon3D(vertices: triangle1, color: colors[index % colors.count]),
                Polygon3D(vertices: triangle2, color: colors[index % colors.count])
            ]
        }.flatMap { $0 }
        
        return Object3D(polygons: polygons)
    }

    static func createPyramid(size: CGFloat = 100, color: Color = .blue) -> Object3D {
        let s = size / 2
        let h = size * 1.5
        
        let vertices = [

            [Vertex3D(x: -s, y: s, z: -s), Vertex3D(x: s, y: s, z: -s), Vertex3D(x: s, y: s, z: s), Vertex3D(x: -s, y: s, z: s)],

            [Vertex3D(x: -s, y: s, z: -s), Vertex3D(x: s, y: s, z: -s), Vertex3D(x: 0, y: -h/2, z: 0)],
            [Vertex3D(x: s, y: s, z: -s), Vertex3D(x: s, y: s, z: s), Vertex3D(x: 0, y: -h/2, z: 0)],
            [Vertex3D(x: s, y: s, z: s), Vertex3D(x: -s, y: s, z: s), Vertex3D(x: 0, y: -h/2, z: 0)],
            [Vertex3D(x: -s, y: s, z: s), Vertex3D(x: -s, y: s, z: -s), Vertex3D(x: 0, y: -h/2, z: 0)]
        ]
        
        let colors: [Color] = [.gray, .red, .green, .blue, .orange]
        
        let polygons = vertices.enumerated().map { index, vertexArray in
            Polygon3D(vertices: vertexArray, color: colors[index % colors.count])
        }
        
        return Object3D(polygons: polygons)
    }

    static func createSphere(radius: CGFloat = 50, subdivisions: Int = 3, color: Color = .cyan) -> Object3D {
        var polygons: [Polygon3D] = []

        let t = (1.0 + sqrt(5.0)) / 2.0
        
        let vertices = [
            Vertex3D(x: -1, y: t, z: 0),
            Vertex3D(x: 1, y: t, z: 0),
            Vertex3D(x: -1, y: -t, z: 0),
            Vertex3D(x: 1, y: -t, z: 0),
            
            Vertex3D(x: 0, y: -1, z: t),
            Vertex3D(x: 0, y: 1, z: t),
            Vertex3D(x: 0, y: -1, z: -t),
            Vertex3D(x: 0, y: 1, z: -t),
            
            Vertex3D(x: t, y: 0, z: -1),
            Vertex3D(x: t, y: 0, z: 1),
            Vertex3D(x: -t, y: 0, z: -1),
            Vertex3D(x: -t, y: 0, z: 1)
        ].map { vertex in
            let length = sqrt(vertex.x * vertex.x + vertex.y * vertex.y + vertex.z * vertex.z)
            return Vertex3D(
                x: vertex.x / length * radius,
                y: vertex.y / length * radius,
                z: vertex.z / length * radius
            )
        }

        let faces = [
            [0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
            [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
            [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
            [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]
        ]
        
        for face in faces {
            let polygon = Polygon3D(
                vertices: [vertices[face[0]], vertices[face[1]], vertices[face[2]]],
                color: color
            )
            polygons.append(polygon)
        }
        
        return Object3D(polygons: polygons)
    }

    static func createPlane(width: CGFloat = 200, height: CGFloat = 200, color: Color = .gray) -> Object3D {
        let w = width / 2
        let h = height / 2
        
        let vertices = [
            Vertex3D(x: -w, y: 0, z: -h),
            Vertex3D(x: w, y: 0, z: -h),
            Vertex3D(x: w, y: 0, z: h),
            Vertex3D(x: -w, y: 0, z: h)
        ]

        let triangle1 = [vertices[0], vertices[1], vertices[2]]
        let triangle2 = [vertices[0], vertices[2], vertices[3]]
        
        let polygons = [
            Polygon3D(vertices: triangle1, color: color),
            Polygon3D(vertices: triangle2, color: color)
        ]
        
        return Object3D(polygons: polygons)
    }
}

struct Object3DView: View {
    let object: Object3D
    var perspective: CGFloat = 500
    var showWireframe: Bool = false
    
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let polygons = object.getTransformedPolygons()

            let sortedPolygons = polygons.sorted { $0.centerZ() > $1.centerZ() }
            
            for polygon in sortedPolygons {
                let projectedPoints = polygon.projected(perspective: perspective)
                let shiftedPoints = projectedPoints.map { CGPoint(x: $0.x + center.x, y: $0.y + center.y) }

                var path = Path()
                if let firstPoint = shiftedPoints.first {
                    path.move(to: firstPoint)
                    for point in shiftedPoints.dropFirst() {
                        path.addLine(to: point)
                    }
                    path.closeSubpath()
                }
                
                context.fill(path, with: .color(polygon.color.opacity(polygon.opacity)))

                if showWireframe {
                    context.stroke(path, with: .color(.black), lineWidth: 1)
                }
            }
        }
    }
}
