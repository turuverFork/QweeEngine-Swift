import SwiftUI
import Combine

class ShaderManager: ObservableObject {
    @Published var lightDirection: (x: Float, y: Float, z: Float) = (0, 0, -1)
    @Published var ambientLight: Float = 0.2
    @Published var diffuseLight: Float = 0.7
    
    func calculateLighting(normal: (x: Float, y: Float, z: Float)) -> Float {
        let dotProduct =
            normal.x * lightDirection.x +
            normal.y * lightDirection.y +
            normal.z * lightDirection.z
        
        let clamped = max(dotProduct, 0)
        return ambientLight + (diffuseLight * clamped)
    }
    
    func applyLighting(to color: Color, intensity: Float) -> Color {
        let comp = color.components
        return Color(
            red: comp.red * Double(intensity),
            green: comp.green * Double(intensity),
            blue: comp.blue * Double(intensity)
        )
    }
}

extension Color {
    var components: (red: Double, green: Double, blue: Double) {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        
        uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
        return (Double(r), Double(g), Double(b))
        #else
        return (1.0, 0.0, 0.0)
        #endif
    }
}

func calculateNormal(_ vertices: [Vertex3D]) -> (x: Float, y: Float, z: Float) {
    guard vertices.count >= 3 else { return (0, 0, 1) }
    
    let v0 = vertices[0]
    let v1 = vertices[1]
    let v2 = vertices[2]
    
    let ux = Float(v1.x - v0.x)
    let uy = Float(v1.y - v0.y)
    let uz = Float(v1.z - v0.z)
    
    let vx = Float(v2.x - v0.x)
    let vy = Float(v2.y - v0.y)
    let vz = Float(v2.z - v0.z)

    let nx = uy * vz - uz * vy
    let ny = uz * vx - ux * vz
    let nz = ux * vy - uy * vx
 
    let length = sqrt(nx * nx + ny * ny + nz * nz)
    guard length > 0 else { return (0, 0, 1) }
    
    return (nx / length, ny / length, nz / length)
}
