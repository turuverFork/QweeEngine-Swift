import SwiftUI
import Combine
import simd

enum CollisionShape {
    case box(size: SIMD3<Float>)
    case sphere(radius: Float)
    case capsule(radius: Float, height: Float)
    case mesh(vertices: [SIMD3<Float>])
}

enum PhysicsBodyType {
    case `static`
    case kinematic
    case dynamic
    case trigger
}

struct PhysicsMaterial {
    var density: Float = 1.0
    var friction: Float = 0.5
    var restitution: Float = 0.2
    var isGhost: Bool = false
}

class PhysicsBody: Identifiable {
    let id = UUID()
    var position: SIMD3<Float> = [0, 0, 0]
    var rotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    var velocity: SIMD3<Float> = [0, 0, 0]
    var angularVelocity: SIMD3<Float> = [0, 0, 0]
    
    var mass: Float = 1.0
    var inverseMass: Float { return mass > 0 ? 1.0 / mass : 0.0 }
    var inertia: SIMD3<Float> = [1, 1, 1]
    var inverseInertia: SIMD3<Float> { return 1.0 / inertia }
    
    var shape: CollisionShape
    var bodyType: PhysicsBodyType
    var material: PhysicsMaterial
    
    var forces: SIMD3<Float> = [0, 0, 0]
    var torques: SIMD3<Float> = [0, 0, 0]
    
    var isSleeping: Bool = false
    var sleepTimer: Float = 0
    
    var aabbMin: SIMD3<Float> = [0, 0, 0]
    var aabbMax: SIMD3<Float> = [0, 0, 0]
    
    init(shape: CollisionShape, bodyType: PhysicsBodyType = .dynamic,
         material: PhysicsMaterial = PhysicsMaterial()) {
        self.shape = shape
        self.bodyType = bodyType
        self.material = material
        updateAABB()
        
        switch shape {
        case .box(let size):
            let volume = size.x * size.y * size.z
            mass = volume * material.density
            inertia = SIMD3<Float>(
                mass * (size.y * size.y + size.z * size.z) / 12,
                mass * (size.x * size.x + size.z * size.z) / 12,
                mass * (size.x * size.x + size.y * size.y) / 12
            )
        case .sphere(let radius):
            let volume = (4.0/3.0) * .pi * pow(radius, 3)
            mass = volume * material.density
            let i = 0.4 * mass * radius * radius
            inertia = SIMD3<Float>(i, i, i)
        case .capsule(let radius, let height):
            let cylinderVolume = .pi * radius * radius * height
            let sphereVolume = (4.0/3.0) * .pi * pow(radius, 3)
            mass = (cylinderVolume + sphereVolume) * material.density
            inertia = SIMD3<Float>(mass, mass, mass)
        case .mesh:
            mass = 1.0 * material.density
            inertia = SIMD3<Float>(1, 1, 1)
        }
    }
    
    func applyForce(_ force: SIMD3<Float>, at point: SIMD3<Float>? = nil) {
        if bodyType == .dynamic && !isSleeping {
            forces += force
            
            if let point = point {
                let r = point - position
                torques += cross(r, force)
            }
        }
    }
    
    func applyImpulse(_ impulse: SIMD3<Float>, at point: SIMD3<Float>? = nil) {
        if bodyType == .dynamic && !isSleeping {
            velocity += impulse * inverseMass
            
            if let point = point {
                let r = point - position
                angularVelocity += cross(r, impulse) * inverseInertia
            }
            
            wakeUp()
        }
    }
    
    func updateAABB() {
        switch shape {
        case .box(let size):
            let halfSize = size / 2
            aabbMin = position - halfSize
            aabbMax = position + halfSize
            
        case .sphere(let radius):
            aabbMin = SIMD3<Float>(position.x - radius, position.y - radius, position.z - radius)
            aabbMax = SIMD3<Float>(position.x + radius, position.y + radius, position.z + radius)
            
        case .capsule(let radius, let height):
            let halfHeight = height / 2
            aabbMin = SIMD3<Float>(
                position.x - radius,
                position.y - halfHeight - radius,
                position.z - radius
            )
            aabbMax = SIMD3<Float>(
                position.x + radius,
                position.y + halfHeight + radius,
                position.z + radius
            )
            
        case .mesh(let vertices):
            if let first = vertices.first {
                var minX = first.x
                var minY = first.y
                var minZ = first.z
                var maxX = first.x
                var maxY = first.y
                var maxZ = first.z
                
                for vertex in vertices {
                    if vertex.x < minX { minX = vertex.x }
                    if vertex.y < minY { minY = vertex.y }
                    if vertex.z < minZ { minZ = vertex.z }
                    if vertex.x > maxX { maxX = vertex.x }
                    if vertex.y > maxY { maxY = vertex.y }
                    if vertex.z > maxZ { maxZ = vertex.z }
                }
                
                aabbMin = SIMD3<Float>(minX, minY, minZ) + position
                aabbMax = SIMD3<Float>(maxX, maxY, maxZ) + position
            }
        }
    }
    
    func wakeUp() {
        isSleeping = false
        sleepTimer = 0
    }
}

struct CollisionInfo {
    var bodyA: PhysicsBody
    var bodyB: PhysicsBody
    var normal: SIMD3<Float>
    var penetration: Float
    var contactPoint: SIMD3<Float>
    var restitution: Float
    var friction: Float
}

class CollisionDetector {
    
    static func checkCollision(_ a: PhysicsBody, _ b: PhysicsBody) -> CollisionInfo? {
        if !aabbOverlap(a, b) {
            return nil
        }
        
        switch (a.shape, b.shape) {
        case (.box(let sizeA), .box(let sizeB)):
            return boxBoxCollision(a: a, sizeA: sizeA, b: b, sizeB: sizeB)
        case (.sphere(let radiusA), .sphere(let radiusB)):
            return sphereSphereCollision(a: a, radiusA: radiusA, b: b, radiusB: radiusB)
        case (.box(let size), .sphere(let radius)):
            return boxSphereCollision(box: a, boxSize: size, sphere: b, sphereRadius: radius)
        case (.sphere(let radius), .box(let size)):
            if let info = boxSphereCollision(box: b, boxSize: size, sphere: a, sphereRadius: radius) {
                return CollisionInfo(
                    bodyA: info.bodyB,
                    bodyB: info.bodyA,
                    normal: -info.normal,
                    penetration: info.penetration,
                    contactPoint: info.contactPoint,
                    restitution: info.restitution,
                    friction: info.friction
                )
            }
        default:
            return simpleCollision(a, b)
        }
        
        return nil
    }
    
    private static func aabbOverlap(_ a: PhysicsBody, _ b: PhysicsBody) -> Bool {
        return (a.aabbMin.x <= b.aabbMax.x && a.aabbMax.x >= b.aabbMin.x) &&
               (a.aabbMin.y <= b.aabbMax.y && a.aabbMax.y >= b.aabbMin.y) &&
               (a.aabbMin.z <= b.aabbMax.z && a.aabbMax.z >= b.aabbMin.z)
    }
    
    private static func boxBoxCollision(a: PhysicsBody, sizeA: SIMD3<Float>,
                                       b: PhysicsBody, sizeB: SIMD3<Float>) -> CollisionInfo? {
        let delta = b.position - a.position
        
        // Calculate absolute delta
        let absDeltaX = abs(delta.x)
        let absDeltaY = abs(delta.y)
        let absDeltaZ = abs(delta.z)
        
        let penetrationX = (sizeA.x + sizeB.x) / 2 - absDeltaX
        let penetrationY = (sizeA.y + sizeB.y) / 2 - absDeltaY
        let penetrationZ = (sizeA.z + sizeB.z) / 2 - absDeltaZ
        
        if penetrationX > 0 && penetrationY > 0 && penetrationZ > 0 {
            let minPenetration = Swift.min(penetrationX, Swift.min(penetrationY, penetrationZ))
            var normal = SIMD3<Float>(0, 0, 0)
            
            if minPenetration == penetrationX {
                normal = SIMD3<Float>(delta.x > 0 ? 1 : -1, 0, 0)
            } else if minPenetration == penetrationY {
                normal = SIMD3<Float>(0, delta.y > 0 ? 1 : -1, 0)
            } else {
                normal = SIMD3<Float>(0, 0, delta.z > 0 ? 1 : -1)
            }
            
            let contactPoint = (a.position + b.position) / 2
            let restitution = Swift.min(a.material.restitution, b.material.restitution)
            let friction = sqrt(a.material.friction * b.material.friction)
            
            return CollisionInfo(
                bodyA: a,
                bodyB: b,
                normal: normal,
                penetration: minPenetration,
                contactPoint: contactPoint,
                restitution: restitution,
                friction: friction
            )
        }
        
        return nil
    }
    
    private static func sphereSphereCollision(a: PhysicsBody, radiusA: Float,
                                             b: PhysicsBody, radiusB: Float) -> CollisionInfo? {
        let delta = b.position - a.position
        let distance = length(delta)
        let totalRadius = radiusA + radiusB
        
        if distance < totalRadius && distance > 0 {
            let normal = normalize(delta)
            let penetration = totalRadius - distance
            let contactPoint = a.position + normal * (radiusA - penetration / 2)
            let restitution = Swift.min(a.material.restitution, b.material.restitution)
            let friction = sqrt(a.material.friction * b.material.friction)
            
            return CollisionInfo(
                bodyA: a,
                bodyB: b,
                normal: normal,
                penetration: penetration,
                contactPoint: contactPoint,
                restitution: restitution,
                friction: friction
            )
        }
        
        return nil
    }
    
    private static func boxSphereCollision(box: PhysicsBody, boxSize: SIMD3<Float>,
                                          sphere: PhysicsBody, sphereRadius: Float) -> CollisionInfo? {
        let halfSize = boxSize / 2
        let localSpherePos = sphere.position - box.position

        let closestX = Swift.max(-halfSize.x, Swift.min(halfSize.x, localSpherePos.x))
        let closestY = Swift.max(-halfSize.y, Swift.min(halfSize.y, localSpherePos.y))
        let closestZ = Swift.max(-halfSize.z, Swift.min(halfSize.z, localSpherePos.z))
        
        let closestPoint = SIMD3<Float>(closestX, closestY, closestZ)
        let delta = localSpherePos - closestPoint
        let distance = length(delta)
        
        if distance < sphereRadius {
            let normal = distance > 0 ? normalize(delta) : SIMD3<Float>(0, 1, 0)
            let penetration = sphereRadius - distance
            let contactPoint = box.position + closestPoint + normal * penetration / 2
            let restitution = Swift.min(box.material.restitution, sphere.material.restitution)
            let friction = sqrt(box.material.friction * sphere.material.friction)
            
            return CollisionInfo(
                bodyA: box,
                bodyB: sphere,
                normal: normal,
                penetration: penetration,
                contactPoint: contactPoint,
                restitution: restitution,
                friction: friction
            )
        }
        
        return nil
    }
    
    private static func simpleCollision(_ a: PhysicsBody, _ b: PhysicsBody) -> CollisionInfo? {
        let sizeA: Float
        let sizeB: Float
        
        switch a.shape {
        case .box(let size):
            sizeA = length(size) / 2
        case .sphere(let radius):
            sizeA = radius
        case .capsule(let radius, _):
            sizeA = radius
        case .mesh:
            sizeA = 1.0
        }
        
        switch b.shape {
        case .box(let size):
            sizeB = length(size) / 2
        case .sphere(let radius):
            sizeB = radius
        case .capsule(let radius, _):
            sizeB = radius
        case .mesh:
            sizeB = 1.0
        }
        
        return sphereSphereCollision(a: a, radiusA: sizeA, b: b, radiusB: sizeB)
    }
}

class PhysicsWorld: ObservableObject {
    @Published var bodies: [PhysicsBody] = []
    @Published var gravity: SIMD3<Float> = [0, -9.81, 0]
    var fixedDeltaTime: Float = 1.0 / 60.0
    var iterations: Int = 10
    @Published var enabled: Bool = true
    
    var useSpatialPartitioning: Bool = false
    var gridSize: Float = 10.0
    var grid: [Int: [PhysicsBody]] = [:]
    
    func addBody(_ body: PhysicsBody) {
        bodies.append(body)
        updateSpatialGrid(body)
    }
    
    func removeBody(_ body: PhysicsBody) {
        bodies.removeAll { $0.id == body.id }
        removeFromSpatialGrid(body)
    }
    
    func update(deltaTime: Float) {
        guard enabled else { return }
        
        let fixedStep = fixedDeltaTime
        var accumulatedTime: Float = 0
        
        while accumulatedTime < deltaTime {
            step(fixedStep)
            accumulatedTime += fixedStep
        }
    }
    
    private func step(_ deltaTime: Float) {
        for body in bodies where body.bodyType == .dynamic {
            if !body.isSleeping {
                body.forces += gravity * body.mass
                body.velocity *= 0.99
                body.angularVelocity *= 0.95
            }
        }
        
        for body in bodies where body.bodyType == .dynamic {
            if !body.isSleeping {
                body.velocity += body.forces * body.inverseMass * deltaTime
                body.angularVelocity += body.torques * body.inverseInertia * deltaTime
                
                body.position += body.velocity * deltaTime
                
                let rotationDelta = simd_quatf(angle: length(body.angularVelocity) * deltaTime,
                                             axis: normalize(body.angularVelocity))
                body.rotation = rotationDelta * body.rotation
                
                body.forces = [0, 0, 0]
                body.torques = [0, 0, 0]
                
                body.updateAABB()
                
                if length(body.velocity) < 0.01 && length(body.angularVelocity) < 0.01 {
                    body.sleepTimer += deltaTime
                    if body.sleepTimer > 2.0 {
                        body.isSleeping = true
                    }
                } else {
                    body.wakeUp()
                }
            }
        }
        
        var collisions: [CollisionInfo] = []
        
        if useSpatialPartitioning {
            updateSpatialGrid()
            collisions = detectCollisionsSpatial()
        } else {
            collisions = detectCollisionsBruteForce()
        }
        
        for _ in 0..<iterations {
            for collision in collisions {
                resolveCollision(collision)
            }
        }
        
        for body in bodies where body.bodyType == .kinematic {
            body.position += body.velocity * deltaTime
            body.updateAABB()
        }
    }
    
    private func detectCollisionsBruteForce() -> [CollisionInfo] {
        var collisions: [CollisionInfo] = []
        
        for i in 0..<bodies.count {
            let bodyA = bodies[i]
            
            for j in (i + 1)..<bodies.count {
                let bodyB = bodies[j]
                
                if bodyA.material.isGhost || bodyB.material.isGhost {
                    continue
                }
                
                if let collision = CollisionDetector.checkCollision(bodyA, bodyB) {
                    collisions.append(collision)
                }
            }
        }
        
        return collisions
    }
    
    private func detectCollisionsSpatial() -> [CollisionInfo] {
        var collisions: [CollisionInfo] = []
        var checkedPairs = Set<String>()
        
        for (_, cellBodies) in grid {
            for i in 0..<cellBodies.count {
                let bodyA = cellBodies[i]
                
                for j in (i + 1)..<cellBodies.count {
                    let bodyB = cellBodies[j]

                    let bodyAId = bodyA.id.uuidString
                    let bodyBId = bodyB.id.uuidString
 
                    let firstId: String
                    let secondId: String
                    
                    if bodyAId < bodyBId {
                        firstId = bodyAId
                        secondId = bodyBId
                    } else {
                        firstId = bodyBId
                        secondId = bodyAId
                    }
                    
                    let pairId = "\(firstId)-\(secondId)"
                    
                    if checkedPairs.contains(pairId) {
                        continue
                    }
                    checkedPairs.insert(pairId)
                    
                    if bodyA.material.isGhost || bodyB.material.isGhost {
                        continue
                    }
                    
                    if let collision = CollisionDetector.checkCollision(bodyA, bodyB) {
                        collisions.append(collision)
                    }
                }
            }
        }
        
        return collisions
    }
    
    private func resolveCollision(_ collision: CollisionInfo) {
        let a = collision.bodyA
        let b = collision.bodyB
        
        let rv = b.velocity - a.velocity
        let velAlongNormal = dot(rv, collision.normal)
        
        if velAlongNormal > 0 {
            return
        }
        
        let e = collision.restitution
        var j = -(1 + e) * velAlongNormal
        j /= a.inverseMass + b.inverseMass
        
        let impulse = collision.normal * j
        a.applyImpulse(-impulse)
        b.applyImpulse(impulse)
        
        let tangent = rv - collision.normal * velAlongNormal
        let tangentLength = length(tangent)
        
        if tangentLength > 0 {
            let tangentNormalized = tangent / tangentLength
            let jt = -dot(rv, tangentNormalized)
            let jtTotal = jt / (a.inverseMass + b.inverseMass)
            
            let frictionImpulse = tangentNormalized * jtTotal * collision.friction
            a.applyImpulse(-frictionImpulse)
            b.applyImpulse(frictionImpulse)
        }
        
        let percent: Float = 0.2
        let slop: Float = 0.01
        let correction = Swift.max(collision.penetration - slop, 0) / (a.inverseMass + b.inverseMass) * percent
        let correctionVector = collision.normal * correction
        
        if a.bodyType == .dynamic {
            a.position -= correctionVector * a.inverseMass
            a.updateAABB()
        }
        
        if b.bodyType == .dynamic {
            b.position += correctionVector * b.inverseMass
            b.updateAABB()
        }
    }

    private func getGridKey(_ position: SIMD3<Float>) -> Int {
        let x = Int((position.x + gridSize * 10) / gridSize)
        let y = Int((position.y + gridSize * 10) / gridSize)
        let z = Int((position.z + gridSize * 10) / gridSize)
        
        return (x & 0xFF) << 16 | (y & 0xFF) << 8 | (z & 0xFF)
    }
    
    private func updateSpatialGrid() {
        grid.removeAll()
        for body in bodies {
            updateSpatialGrid(body)
        }
    }
    
    private func updateSpatialGrid(_ body: PhysicsBody) {
        guard useSpatialPartitioning else { return }
        
        let centerKey = getGridKey(body.position)
        
        if grid[centerKey] == nil {
            grid[centerKey] = []
        }
        
        if !grid[centerKey]!.contains(where: { $0.id == body.id }) {
            grid[centerKey]!.append(body)
        }
    }
    
    private func removeFromSpatialGrid(_ body: PhysicsBody) {
        guard useSpatialPartitioning else { return }
        
        for (key, var bodiesInCell) in grid {
            bodiesInCell.removeAll { $0.id == body.id }
            grid[key] = bodiesInCell
        }
    }

    struct RaycastResult {
        var body: PhysicsBody
        var point: SIMD3<Float>
        var normal: SIMD3<Float>
        var distance: Float
    }
    
    func raycast(from: SIMD3<Float>, to: SIMD3<Float>) -> RaycastResult? {
        let direction = to - from
        let maxDistance = length(direction)
        let normalizedDirection = normalize(direction)
        
        var closestResult: RaycastResult?
        var closestDistance = Float.greatestFiniteMagnitude
        
        for body in bodies {
            if let hit = raycastBody(body, from: from, direction: normalizedDirection, maxDistance: maxDistance) {
                if hit.distance < closestDistance {
                    closestDistance = hit.distance
                    closestResult = hit
                }
            }
        }
        
        return closestResult
    }
    
    private func raycastBody(_ body: PhysicsBody, from: SIMD3<Float>,
                            direction: SIMD3<Float>, maxDistance: Float) -> RaycastResult? {
        
        if !rayAABBIntersect(from: from, direction: direction, aabbMin: body.aabbMin, aabbMax: body.aabbMax) {
            return nil
        }
        
        switch body.shape {
        case .box(let size):
            if let hit = rayBoxIntersect(from: from, direction: direction,
                                        center: body.position, size: size) {
                return RaycastResult(body: body, point: hit.point,
                                   normal: hit.normal, distance: hit.distance)
            }
        case .sphere(let radius):
            if let hit = raySphereIntersect(from: from, direction: direction,
                                          center: body.position, radius: radius) {
                return RaycastResult(body: body, point: hit.point,
                                   normal: hit.normal, distance: hit.distance)
            }
        default:
            let hitPoint = from + direction * maxDistance / 2
            return RaycastResult(body: body, point: hitPoint,
                               normal: SIMD3<Float>(0, 1, 0), distance: maxDistance / 2)
        }
        
        return nil
    }
    
    private func rayAABBIntersect(from: SIMD3<Float>, direction: SIMD3<Float>,
                                 aabbMin: SIMD3<Float>, aabbMax: SIMD3<Float>) -> Bool {
        var tmin: Float = 0
        var tmax = Float.greatestFiniteMagnitude
        
        for i in 0..<3 {
            if abs(direction[i]) < 0.0001 {
                if from[i] < aabbMin[i] || from[i] > aabbMax[i] {
                    return false
                }
            } else {
                let invD = 1.0 / direction[i]
                var t1 = (aabbMin[i] - from[i]) * invD
                var t2 = (aabbMax[i] - from[i]) * invD
                
                if t1 > t2 {
                    let temp = t1
                    t1 = t2
                    t2 = temp
                }
                
                tmin = Swift.max(tmin, t1)
                tmax = Swift.min(tmax, t2)
                
                if tmin > tmax {
                    return false
                }
            }
        }
        
        return true
    }
    
    private func rayBoxIntersect(from: SIMD3<Float>, direction: SIMD3<Float>,
                                center: SIMD3<Float>, size: SIMD3<Float>) -> (point: SIMD3<Float>, normal: SIMD3<Float>, distance: Float)? {
        let halfSize = size / 2
        let min = center - halfSize
        let max = center + halfSize
        
        var tmin = (min.x - from.x) / direction.x
        var tmax = (max.x - from.x) / direction.x
        
        if tmin > tmax {
            let temp = tmin
            tmin = tmax
            tmax = temp
        }
        
        var tymin = (min.y - from.y) / direction.y
        var tymax = (max.y - from.y) / direction.y
        
        if tymin > tymax {
            let temp = tymin
            tymin = tymax
            tymax = temp
        }
        
        if tmin > tymax || tymin > tmax {
            return nil
        }
        
        tmin = Swift.max(tmin, tymin)
        tmax = Swift.min(tmax, tymax)
        
        var tzmin = (min.z - from.z) / direction.z
        var tzmax = (max.z - from.z) / direction.z
        
        if tzmin > tzmax {
            let temp = tzmin
            tzmin = tzmax
            tzmax = temp
        }
        
        if tmin > tzmax || tzmin > tmax {
            return nil
        }
        
        tmin = Swift.max(tmin, tzmin)
        
        if tmin < 0 {
            return nil
        }
        
        let hitPoint = from + direction * tmin
        
        var normal = SIMD3<Float>(0, 0, 0)
        let localPoint = hitPoint - center
        
        let xDist = abs(halfSize.x - abs(localPoint.x))
        let yDist = abs(halfSize.y - abs(localPoint.y))
        let zDist = abs(halfSize.z - abs(localPoint.z))
        
        let minDist = Swift.min(xDist, Swift.min(yDist, zDist))
        
        if minDist == xDist {
            normal = SIMD3<Float>(localPoint.x > 0 ? 1 : -1, 0, 0)
        } else if minDist == yDist {
            normal = SIMD3<Float>(0, localPoint.y > 0 ? 1 : -1, 0)
        } else {
            normal = SIMD3<Float>(0, 0, localPoint.z > 0 ? 1 : -1)
        }
        
        return (hitPoint, normal, tmin)
    }
    
    private func raySphereIntersect(from: SIMD3<Float>, direction: SIMD3<Float>,
                                   center: SIMD3<Float>, radius: Float) -> (point: SIMD3<Float>, normal: SIMD3<Float>, distance: Float)? {
        let oc = from - center
        let a = dot(direction, direction)
        let b = 2.0 * dot(oc, direction)
        let c = dot(oc, oc) - radius * radius
        
        let discriminant = b * b - 4 * a * c
        
        if discriminant < 0 {
            return nil
        }
        
        let sqrtDiscriminant = sqrt(discriminant)
        let t1 = (-b - sqrtDiscriminant) / (2 * a)
        let t2 = (-b + sqrtDiscriminant) / (2 * a)
        
        let t = t1 >= 0 ? t1 : (t2 >= 0 ? t2 : nil)
        
        guard let hitDistance = t, hitDistance > 0 else {
            return nil
        }
        
        let hitPoint = from + direction * hitDistance
        let normal = normalize(hitPoint - center)
        
        return (hitPoint, normal, hitDistance)
    }
}

struct PhysicsDebugView: View {
    @ObservedObject var world: PhysicsWorld
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Physics Debug")
                .font(.headline)
                .foregroundColor(.yellow)
            
            Text("Bodies: \(world.bodies.count)")
                .foregroundColor(.white)
            
            Text("Gravity: \(String(format: "%.1f", world.gravity.y)) m/s²")
                .foregroundColor(.white)
            
            Text("Enabled: \(world.enabled ? "Yes" : "No")")
                .foregroundColor(world.enabled ? .green : .red)
            
            Divider()
                .background(Color.white)
            
            ForEach(world.bodies.prefix(5)) { body in
                VStack(alignment: .leading) {
                    Text("Body: \(String(describing: body.shape))")
                        .foregroundColor(.white)
                    Text("Pos: \(String(format: "%.1f", body.position.x)), \(String(format: "%.1f", body.position.y)), \(String(format: "%.1f", body.position.z))")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("Vel: \(String(format: "%.1f", length(body.velocity)))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .cornerRadius(10)
    }
}
