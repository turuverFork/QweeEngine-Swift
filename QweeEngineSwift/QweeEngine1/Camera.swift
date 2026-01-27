import SwiftUI
import Combine
import simd

enum CameraMode {
    case freeLook
    case firstPerson
    case thirdPerson
    case orbit
    case fixed
}

enum ProjectionType {
    case perspective
    case orthographic
}

class Camera: ObservableObject {
    @Published var position: SIMD3<Float> = [0, 2, 5]
    @Published var target: SIMD3<Float> = [0, 0, 0]
    @Published var up: SIMD3<Float> = [0, 1, 0]
    
    @Published var mode: CameraMode = .freeLook
    @Published var projectionType: ProjectionType = .perspective

    var fov: Float = 60.0
    var aspectRatio: Float = 16.0 / 9.0
    var nearPlane: Float = 0.1
    var farPlane: Float = 1000.0
    
    var orthographicSize: Float = 10.0

    var moveSpeed: Float = 5.0
    var rotationSpeed: Float = 0.3
    var zoomSpeed: Float = 2.0

    var orbitDistance: Float = 5.0
    var orbitTarget: SIMD3<Float> = [0, 0, 0]
    var orbitAngle: SIMD2<Float> = [0, 0]

    var followTarget: SIMD3<Float>?
    var followDistance: Float = 5.0
    var followHeight: Float = 2.0

    private(set) var viewMatrix: [Float] = []
    private(set) var projectionMatrix: [Float] = []
    private(set) var viewProjectionMatrix: [Float] = []
    
    private var forward: SIMD3<Float> = [0, 0, -1]
    private var right: SIMD3<Float> = [1, 0, 0]
    
    init() {
        updateMatrices()
    }

    
    func update(deltaTime: Float, input: InputState? = nil) {
        switch mode {
        case .freeLook:
            updateFreeLook(deltaTime: deltaTime, input: input)
        case .firstPerson:
            updateFirstPerson(deltaTime: deltaTime, input: input)
        case .thirdPerson:
            updateThirdPerson(deltaTime: deltaTime, input: input)
        case .orbit:
            updateOrbit(deltaTime: deltaTime, input: input)
        case .fixed:
            break
        }
        
        updateMatrices()
    }
    
    private func updateFreeLook(deltaTime: Float, input: InputState?) {
        guard let input = input else { return }

        if input.mouseDown {
            let sensitivity: Float = 0.002
            let yaw = Float(input.mouseDelta.width) * sensitivity
            let pitch = Float(input.mouseDelta.height) * sensitivity
            
            rotate(yaw: yaw, pitch: pitch)
        }

        var movement = SIMD3<Float>(0, 0, 0)
        
        if input.isKeyPressed(.w) { movement += forward }
        if input.isKeyPressed(.s) { movement -= forward }
        if input.isKeyPressed(.a) { movement -= right }
        if input.isKeyPressed(.d) { movement += right }
        if input.isKeyPressed(.space) { movement.y += 1 }
        if input.isKeyPressed(.shift) { movement.y -= 1 }

        if length(movement) > 0 {
            movement = normalize(movement)
        }

        position += movement * moveSpeed * deltaTime
        target = position + forward
    }
    
    private func updateFirstPerson(deltaTime: Float, input: InputState?) {
        guard let input = input else { return }

        if input.mouseDown {
            let sensitivity: Float = 0.002
            let yaw = Float(input.mouseDelta.width) * sensitivity
            let pitch = Float(input.mouseDelta.height) * sensitivity
            
            rotate(yaw: yaw, pitch: pitch)
        }

        var movement = SIMD3<Float>(0, 0, 0)
        
        if input.isKeyPressed(.w) { movement.z -= 1 }
        if input.isKeyPressed(.s) { movement.z += 1 }
        if input.isKeyPressed(.a) { movement.x -= 1 }
        if input.isKeyPressed(.d) { movement.x += 1 }

        if length(movement) > 0 {
            movement = normalize(movement)
            let forwardFlat = normalize(SIMD3<Float>(forward.x, 0, forward.z))
            let rightFlat = normalize(SIMD3<Float>(right.x, 0, right.z))
            
            let worldMovement = forwardFlat * movement.z + rightFlat * movement.x
            position += worldMovement * moveSpeed * deltaTime
        }
        
        target = position + forward
    }
    
    private func updateThirdPerson(deltaTime: Float, input: InputState?) {
        guard let targetPos = followTarget else { return }

        let forward = normalize(targetPos - position)
        let desiredPosition = targetPos - forward * followDistance + SIMD3<Float>(0, followHeight, 0)

        let smoothSpeed: Float = 5.0
        position = mix(position, desiredPosition, t: smoothSpeed * deltaTime)

        target = targetPos
    }
    
    private func updateOrbit(deltaTime: Float, input: InputState?) {
        guard let input = input else { return }

        if input.mouseDown {
            let sensitivity: Float = 0.01
            orbitAngle.x += Float(input.mouseDelta.width) * sensitivity
            orbitAngle.y += Float(input.mouseDelta.height) * sensitivity

            orbitAngle.y = max(-Float.pi/2 + 0.1, min(Float.pi/2 - 0.1, orbitAngle.y))
        }

        orbitDistance += Float(input.scrollDelta) * zoomSpeed * deltaTime
        orbitDistance = max(1.0, min(50.0, orbitDistance))

        let cosYaw = cos(orbitAngle.x)
        let sinYaw = sin(orbitAngle.x)
        let cosPitch = cos(orbitAngle.y)
        let sinPitch = sin(orbitAngle.y)
        
        let offset = SIMD3<Float>(
            orbitDistance * cosPitch * sinYaw,
            orbitDistance * sinPitch,
            orbitDistance * cosPitch * cosYaw
        )
        
        position = orbitTarget + offset
        target = orbitTarget
    }

    
    func rotate(yaw: Float, pitch: Float) {
        forward = normalize(SIMD3<Float>(
            sin(yaw) * cos(pitch),
            sin(pitch),
            cos(yaw) * cos(pitch)
        ))

        right = normalize(cross(forward, SIMD3<Float>(0, 1, 0)))

        target = position + forward
    }
    
    func lookAt(target: SIMD3<Float>) {
        self.target = target
        forward = normalize(target - position)
        right = normalize(cross(forward, up))
    }
    
    func setPosition(_ position: SIMD3<Float>) {
        self.position = position
        target = position + forward
    }
    
    func move(_ offset: SIMD3<Float>) {
        position += offset
        target += offset
    }
    
    func zoom(_ amount: Float) {
        switch mode {
        case .orbit:
            orbitDistance = max(1.0, min(50.0, orbitDistance + amount))
        default:
            position += forward * amount
            target = position + forward
        }
    }
    
    func setOrbitTarget(_ target: SIMD3<Float>) {
        orbitTarget = target
        mode = .orbit

        let direction = normalize(position - target)
        orbitAngle.y = asin(direction.y)
        orbitAngle.x = atan2(direction.x, direction.z)
    }
    
    func follow(target: SIMD3<Float>, distance: Float = 5.0, height: Float = 2.0) {
        followTarget = target
        followDistance = distance
        followHeight = height
        mode = .thirdPerson
    }
    
    func reset() {
        position = [0, 2, 5]
        target = [0, 0, 0]
        up = [0, 1, 0]
        forward = [0, 0, -1]
        right = [1, 0, 0]
        orbitAngle = [0, 0]
        orbitDistance = 5.0
        updateMatrices()
    }

    
    private func updateMatrices() {
        viewMatrix = calculateViewMatrix()
        projectionMatrix = calculateProjectionMatrix()
        viewProjectionMatrix = multiplyMatrices(projectionMatrix, viewMatrix)
    }
    
    private func calculateViewMatrix() -> [Float] {
        return Matrix4x4.lookAt(eye: position, target: target, up: up)
    }
    
    private func calculateProjectionMatrix() -> [Float] {
        switch projectionType {
        case .perspective:
            return Matrix4x4.perspective(
                fov: fov * .pi / 180.0,
                aspect: aspectRatio,
                near: nearPlane,
                far: farPlane
            )
        case .orthographic:
            let halfWidth = orthographicSize * aspectRatio
            let halfHeight = orthographicSize
            return Matrix4x4.orthographic(
                left: -halfWidth,
                right: halfWidth,
                bottom: -halfHeight,
                top: halfHeight,
                near: nearPlane,
                far: farPlane
            )
        }
    }

    
    func screenToWorld(screenPoint: SIMD2<Float>, screenSize: SIMD2<Float>) -> SIMD3<Float> {
        // Convert screen coordinates to world space (simplified)
        let ndc = SIMD2<Float>(
            2.0 * screenPoint.x / screenSize.x - 1.0,
            1.0 - 2.0 * screenPoint.y / screenSize.y
        )

        return position + forward * 10.0
    }
    
    func worldToScreen(worldPoint: SIMD3<Float>, screenSize: SIMD2<Float>) -> SIMD2<Float>? {
        let point4 = SIMD4<Float>(worldPoint.x, worldPoint.y, worldPoint.z, 1.0)

        let clipSpace = multiplyMatrixVector(viewProjectionMatrix, point4)

        if clipSpace.w <= 0 { return nil }
     
        let ndc = SIMD3<Float>(
            clipSpace.x / clipSpace.w,
            clipSpace.y / clipSpace.w,
            clipSpace.z / clipSpace.w
        )

        let screenX = (ndc.x + 1.0) * 0.5 * screenSize.x
        let screenY = (1.0 - ndc.y) * 0.5 * screenSize.y
        
        return SIMD2<Float>(screenX, screenY)
    }
    
    func getFrustumCorners() -> [SIMD3<Float>] {
        let tanFov = tan(fov * 0.5 * .pi / 180.0)
        let aspect = aspectRatio
        
        let nearHeight = nearPlane * tanFov
        let nearWidth = nearHeight * aspect
        let farHeight = farPlane * tanFov
        let farWidth = farHeight * aspect
        
        let nearCenter = position + forward * nearPlane
        let farCenter = position + forward * farPlane
        
        return [
            nearCenter + up * nearHeight - right * nearWidth,
            nearCenter + up * nearHeight + right * nearWidth,
            nearCenter - up * nearHeight - right * nearWidth,
            nearCenter - up * nearHeight + right * nearWidth,

            farCenter + up * farHeight - right * farWidth,
            farCenter + up * farHeight + right * farWidth,
            farCenter - up * farHeight - right * farWidth,
            farCenter - up * farHeight + right * farWidth
        ]
    }
}

extension Matrix4x4 {
    static func orthographic(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> [Float] {
        let rml = right - left
        let tmb = top - bottom
        let fmn = far - near
        
        return [
            2.0 / rml, 0, 0, 0,
            0, 2.0 / tmb, 0, 0,
            0, 0, -2.0 / fmn, 0,
            -(right + left) / rml, -(top + bottom) / tmb, -(far + near) / fmn, 1
        ]
    }
}

private func multiplyMatrices(_ a: [Float], _ b: [Float]) -> [Float] {
    var result = [Float](repeating: 0, count: 16)
    
    for i in 0..<4 {
        for j in 0..<4 {
            var sum: Float = 0
            for k in 0..<4 {
                sum += a[i * 4 + k] * b[k * 4 + j]
            }
            result[i * 4 + j] = sum
        }
    }
    
    return result
}

private func multiplyMatrixVector(_ matrix: [Float], _ vector: SIMD4<Float>) -> SIMD4<Float> {
    let x = matrix[0] * vector.x + matrix[1] * vector.y + matrix[2] * vector.z + matrix[3] * vector.w
    let y = matrix[4] * vector.x + matrix[5] * vector.y + matrix[6] * vector.z + matrix[7] * vector.w
    let z = matrix[8] * vector.x + matrix[9] * vector.y + matrix[10] * vector.z + matrix[11] * vector.w
    let w = matrix[12] * vector.x + matrix[13] * vector.y + matrix[14] * vector.z + matrix[15] * vector.w
    
    return SIMD4<Float>(x, y, z, w)
}

private func length(_ vector: SIMD3<Float>) -> Float {
    return sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
}

private func normalize(_ vector: SIMD3<Float>) -> SIMD3<Float> {
    let len = length(vector)
    guard len > 0 else { return SIMD3<Float>(0, 0, 0) }
    return vector / len
}

private func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, t: Float) -> SIMD3<Float> {
    return a + (b - a) * t
}

class CameraController {
    private let camera: Camera
    private let inputManager: InputManager
    
    init(camera: Camera, inputManager: InputManager) {
        self.camera = camera
        self.inputManager = inputManager
    }
    
    func update(deltaTime: Float) {
        camera.update(deltaTime: deltaTime, input: inputManager.inputState)

        if inputManager.inputState.isKeyPressed(.one) {
            camera.mode = .freeLook
        } else if inputManager.inputState.isKeyPressed(.two) {
            camera.mode = .firstPerson
        } else if inputManager.inputState.isKeyPressed(.three) {
            camera.mode = .orbit
        } else if inputManager.inputState.isKeyPressed(.four) {
            camera.mode = .thirdPerson
        }

        if inputManager.inputState.isKeyPressed(.escape) {
            camera.reset()
        }
    }
}
