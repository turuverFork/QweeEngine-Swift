# QweeEngine

A lightweight, real-time 3D rendering engine built entirely with SwiftUI and Swift. QweeEngine brings real-time 3D graphics capabilities to SwiftUI applications with a clean, modern API and support for multiple shaders and materials.

## ✨ Features

### 🎨 Multiple Shading Models
- **Flat Shading** - Simple solid color rendering
- **Phong Shading** - Realistic lighting with specular highlights
- **Toon/Cel Shading** - Stylized cartoon rendering
- **Wireframe** - Edge visualization mode
- **Depth Shading** - Fog and distance-based effects
- **Normal Visualization** - Surface normal color mapping
- **Emissive Materials** - Glowing, self-illuminated surfaces
- **Gradient Shading** - Smooth color transitions

### 🧱 Built-in 3D Primitives
- **Cube** - Complete 6-sided cube with individual face colors
- **Pyramid** - 5-faced pyramid structure
- **Sphere** - Approximated sphere using icosahedron subdivision
- **Plane** - Flat surface for terrain or platforms
- **Custom Polygons** - Create any shape with n vertices

### ⚡ Real-time Performance
- Painter's algorithm for depth sorting
- Vertex transformation pipelines
- Real-time lighting calculations
- Smooth 60 FPS animations
- Efficient polygon rasterization

### 🎮 Interactive Controls
- Real-time object rotation
- Dynamic lighting manipulation
- Material property adjustments
- Camera perspective controls
- Wireframe toggle

## 🚀 Quick Start

### Installation

Simply add the source files to your SwiftUI project:

1. Add `Polygon.swift` for 3D geometry
2. Add `Shaders.swift` for lighting and materials
3. Add `test.txt` for advanced shader implementations

### Basic Usage

```swift
import SwiftUI
import QweeEngine

struct My3DView: View {
    @State private var cube = ObjectFactory.createCube(size: 100)
    @State private var rotation: Double = 0
    
    var body: some View {
        Object3DView(object: cube, perspective: 500, showWireframe: false)
            .onAppear {
                withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}
```

### Creating Custom Objects

```swift
// Create a custom pyramid
let pyramidVertices = [
    Vertex3D(x: -50, y: 50, z: -50),
    Vertex3D(x: 50, y: 50, z: -50),
    Vertex3D(x: 0, y: -50, z: 0)
]

let pyramid = Polygon3D(vertices: pyramidVertices, color: .blue)
let pyramidObject = Object3D(polygons: [pyramid])
```

### Applying Shaders

```swift
let shaderManager = ShaderManager()
shaderManager.activeShader = .phong
shaderManager.lightDirection = SIMD3<Float>(0.5, 1, -0.5)

// Apply to polygon
let normal = ShaderProcessor.calculateNormal(vertices)
let shadedColor = shaderManager.applyShader(to: polygon, normal: normal)
```

## 📁 Project Structure

```
QweeEngine/
├── Polygon.swift              # Core geometry types
├── Shaders.swift             # Lighting and shading systems
├── test.txt                  # Advanced shader implementations
├── Contents.json             # Asset catalog configurations
└── QweeEngine1App.swift      # App entry point
```

## 🛠️ Core Components

### `Vertex3D`
3D vertex with x, y, z coordinates and transformation methods.

### `Polygon3D`
Collection of vertices forming a 3D surface with material properties.

### `Object3D`
Complete 3D object containing multiple polygons with position, rotation, and scale.

### `ShaderManager`
Central controller for shader selection, lighting, and material effects.

### `ObjectFactory`
Factory methods for creating common 3D shapes.

## 🎯 Shader Examples

### Phong Shading
```swift
ShaderProcessor.phongColor(
    baseColor: .red,
    normal: normal,
    lightDirection: SIMD3<Float>(0, 1, -0.5),
    ambient: 0.1,
    diffuse: 0.7,
    specular: 0.2
)
```

### Toon Shading
```swift
ShaderProcessor.toonColor(
    baseColor: .blue,
    normal: normal,
    lightDirection: SIMD3<Float>(0, 0, -1)
)
```

### Emissive Material
```swift
ShaderProcessor.emissiveColor(
    baseColor: .cyan,
    intensity: 1.5,
    time: Date().timeIntervalSince1970
)
```

## 🔧 Configuration

### Lighting Settings
```swift
shaderManager.ambientLight = .white.opacity(0.2)
shaderManager.lightDirection = SIMD3<Float>(sin(angle), 0.5, cos(angle))
shaderManager.lightingEnabled = true
```

### Material Properties
```swift
let glassMaterial = Material(
    baseColor: .white,
    shaderType: .flat,
    metallic: 0.0,
    roughness: 0.0,
    emission: 0.0,
    transparency: 0.8
)
```

## 📱 Requirements

- iOS 14.0+ / macOS 11.0+
- Swift 5.5+
- Xcode 13.0+

## 🎨 Customization

### Creating Custom Shaders
Extend the `ShaderProcessor` class with your own shading algorithms:

```swift
extension ShaderProcessor {
    static func myCustomShader(
        baseColor: Color,
        normal: SIMD3<Float>,
        customParam: Double
    ) -> Color {
        // Your shading logic here
        return modifiedColor
    }
}
```

### Adding New Primitives
Create new factory methods in `ObjectFactory`:

```swift
static func createTorus(radius: CGFloat, tubeRadius: CGFloat, color: Color) -> Object3D {
    // Implementation
}
```

## 📄 License

QweeEngine is available under the MIT license. See the LICENSE file for more info.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📚 Learn More

For more advanced usage and examples, explore the shader implementations in `test.txt` which include:
- Matrix transformations
- Vertex shader functions
- Post-processing effects
- Material system
- Advanced lighting models

## 🎮 Demo

Try the included demo app to see QweeEngine in action with:
- Rotating 3D cube with dynamic lighting
- Real-time shader switching
- Interactive camera controls
- Material property adjustments

---

**QweeEngine** - Bringing 3D graphics to SwiftUI, one polygon at a time.
