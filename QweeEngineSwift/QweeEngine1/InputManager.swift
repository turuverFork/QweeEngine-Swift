import SwiftUI
import Combine
import simd

enum KeyCode: UInt16 {
    case w = 13
    case a = 0
    case s = 1
    case d = 2
    case space = 49
    case shift = 56
    case escape = 53
    case enter = 36
    case up = 126
    case down = 125
    case left = 123
    case right = 124
    case q = 12
    case e = 14
    case r = 15
    case f = 3
    case c = 8
    case v = 9
    case one = 18
    case two = 19
    case three = 20
    case four = 21
}

struct InputState {
    var keysPressed: Set<KeyCode> = []
    var mousePosition: CGPoint = .zero
    var mouseDelta: CGSize = .zero
    var mouseDown: Bool = false
    var scrollDelta: CGFloat = 0
    
    func isKeyPressed(_ key: KeyCode) -> Bool {
        return keysPressed.contains(key)
    }
    
    var movementVector: SIMD2<Float> {
        var vector = SIMD2<Float>(0, 0)
        
        if isKeyPressed(.w) { vector.y += 1 }
        if isKeyPressed(.s) { vector.y -= 1 }
        if isKeyPressed(.a) { vector.x -= 1 }
        if isKeyPressed(.d) { vector.x += 1 }

        if vector.x != 0 || vector.y != 0 {
            let length = sqrt(vector.x * vector.x + vector.y * vector.y)
            vector.x /= length
            vector.y /= length
        }
        
        return vector
    }
}

class InputManager: ObservableObject {
    @Published var inputState = InputState()
    private var keyMonitor: Any?
    private var mouseMonitor: Any?
    
    init() {
        setupKeyboardMonitoring()
        setupMouseMonitoring()
    }
    
    deinit {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    private func setupKeyboardMonitoring() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self = self else { return event }
            
            if event.type == .keyDown {
                if let keyCode = KeyCode(rawValue: event.keyCode) {
                    DispatchQueue.main.async {
                        self.inputState.keysPressed.insert(keyCode)
                    }
                }
            } else if event.type == .keyUp {
                if let keyCode = KeyCode(rawValue: event.keyCode) {
                    DispatchQueue.main.async {
                        self.inputState.keysPressed.remove(keyCode)
                    }
                }
            }
            
            return event
        }
    }
    
    private func setupMouseMonitoring() {
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .leftMouseUp, .scrollWheel]) { [weak self] event in
            guard let self = self else { return event }
            
            DispatchQueue.main.async {
                switch event.type {
                case .mouseMoved:
                    self.inputState.mouseDelta = CGSize(width: event.deltaX, height: event.deltaY)
                    self.inputState.mousePosition = event.locationInWindow
                    
                case .leftMouseDown:
                    self.inputState.mouseDown = true
                    
                case .leftMouseUp:
                    self.inputState.mouseDown = false
                    
                case .scrollWheel:
                    self.inputState.scrollDelta = event.deltaY
                    
                default:
                    break
                }
            }
            
            return event
        }
    }
    
    func update() {

        inputState.mouseDelta = .zero
        inputState.scrollDelta = 0
    }

    func isMovingForward() -> Bool { inputState.isKeyPressed(.w) }
    func isMovingBackward() -> Bool { inputState.isKeyPressed(.s) }
    func isMovingLeft() -> Bool { inputState.isKeyPressed(.a) }
    func isMovingRight() -> Bool { inputState.isKeyPressed(.d) }
    func isJumping() -> Bool { inputState.isKeyPressed(.space) }
    func isRunning() -> Bool { inputState.isKeyPressed(.shift) }
    func isInteracting() -> Bool { inputState.isKeyPressed(.e) }
    
    func getMovementVector() -> SIMD3<Float> {
        let vec2 = inputState.movementVector
        var vec3 = SIMD3<Float>(vec2.x, 0, vec2.y)

        if inputState.isKeyPressed(.space) {
            vec3.y += 1
        }
        if inputState.isKeyPressed(.shift) {
            vec3.y -= 1
        }
        
        return vec3
    }
}

struct VectorMath {
    static func length(_ vector: SIMD3<Float>) -> Float {
        return sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
    }
    
    static func normalize(_ vector: SIMD3<Float>) -> SIMD3<Float> {
        let len = length(vector)
        guard len > 0 else { return SIMD3<Float>(0, 0, 0) }
        return SIMD3<Float>(vector.x / len, vector.y / len, vector.z / len)
    }
    
    static func dot(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        return a.x * b.x + a.y * b.y + a.z * b.z
    }
    
    static func cross(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> {
        return SIMD3<Float>(
            a.y * b.z - a.z * b.y,
            a.z * b.x - a.x * b.z,
            a.x * b.y - a.y * b.x
        )
    }
}

struct Matrix4x4 {
    static func identity() -> [Float] {
        return [
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1
        ]
    }
    
    static func translation(_ x: Float, _ y: Float, _ z: Float) -> [Float] {
        return [
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            x, y, z, 1
        ]
    }
    
    static func rotationX(_ angle: Float) -> [Float] {
        let c = cos(angle)
        let s = sin(angle)
        return [
            1, 0, 0, 0,
            0, c, s, 0,
            0, -s, c, 0,
            0, 0, 0, 1
        ]
    }
    
    static func rotationY(_ angle: Float) -> [Float] {
        let c = cos(angle)
        let s = sin(angle)
        return [
            c, 0, -s, 0,
            0, 1, 0, 0,
            s, 0, c, 0,
            0, 0, 0, 1
        ]
    }
    
    static func lookAt(eye: SIMD3<Float>, target: SIMD3<Float>, up: SIMD3<Float>) -> [Float] {
        let z = VectorMath.normalize(eye - target)
        let x = VectorMath.normalize(VectorMath.cross(up, z))
        let y = VectorMath.cross(z, x)
        
        return [
            x.x, y.x, z.x, 0,
            x.y, y.y, z.y, 0,
            x.z, y.z, z.z, 0,
            -VectorMath.dot(x, eye), -VectorMath.dot(y, eye), -VectorMath.dot(z, eye), 1
        ]
    }
    
    static func perspective(fov: Float, aspect: Float, near: Float, far: Float) -> [Float] {
        let yScale = 1 / tan(fov * 0.5)
        let xScale = yScale / aspect
        let zScale = far / (far - near)
        let wzScale = -far * near / (far - near)
        
        return [
            xScale, 0, 0, 0,
            0, yScale, 0, 0,
            0, 0, zScale, 1,
            0, 0, wzScale, 0
        ]
    }
}

struct SimpleCamera {
    var position: SIMD3<Float> = [0, 0, 5]
    var target: SIMD3<Float> = [0, 0, 0]
    var up: SIMD3<Float> = [0, 1, 0]
    
    var fov: Float = 45
    var aspect: Float = 16/9
    var near: Float = 0.1
    var far: Float = 100
    
    func getViewMatrix() -> [Float] {
        return Matrix4x4.lookAt(eye: position, target: target, up: up)
    }
    
    func getProjectionMatrix() -> [Float] {
        return Matrix4x4.perspective(fov: fov, aspect: aspect, near: near, far: far)
    }
}

class PlayerController {
    var position: SIMD3<Float> = [0, 0, 0]
    var rotation: SIMD3<Float> = [0, 0, 0]
    var velocity: SIMD3<Float> = [0, 0, 0]
    
    let moveSpeed: Float = 5.0
    let lookSpeed: Float = 0.002
    let jumpForce: Float = 5.0
    let gravity: Float = -9.8
    var isGrounded: Bool = true
    
    func update(deltaTime: Float, input: InputState) {

        rotation.y += Float(input.mouseDelta.width) * lookSpeed
        rotation.x -= Float(input.mouseDelta.height) * lookSpeed

        rotation.x = max(-Float.pi/2, min(Float.pi/2, rotation.x))

        let forward = SIMD3<Float>(
            sin(rotation.y),
            0,
            cos(rotation.y)
        )
        
        let right = SIMD3<Float>(
            cos(rotation.y),
            0,
            -sin(rotation.y)
        )

        var moveDirection = SIMD3<Float>(0, 0, 0)
        
        if input.isKeyPressed(.w) {
            moveDirection += forward
        }
        if input.isKeyPressed(.s) {
            moveDirection -= forward
        }
        if input.isKeyPressed(.a) {
            moveDirection -= right
        }
        if input.isKeyPressed(.d) {
            moveDirection += right
        }

        if VectorMath.length(moveDirection) > 0 {
            moveDirection = VectorMath.normalize(moveDirection)
        }

        velocity.x = moveDirection.x * moveSpeed
        velocity.z = moveDirection.z * moveSpeed

        if input.isKeyPressed(.space) && isGrounded {
            velocity.y = jumpForce
            isGrounded = false
        }

        if !isGrounded {
            velocity.y += gravity * deltaTime
        }

        position += velocity * deltaTime

        if position.y < 0 {
            position.y = 0
            velocity.y = 0
            isGrounded = true
        }
    }
    
    func getViewMatrix() -> [Float] {
        let translation = Matrix4x4.translation(position.x, position.y, position.z)
        let rotationX = Matrix4x4.rotationX(rotation.x)
        let rotationY = Matrix4x4.rotationY(rotation.y)
        
        return translation
    }
}
