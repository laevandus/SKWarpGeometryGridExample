//: A SpriteKit based Playground

import PlaygroundSupport
import SpriteKit

extension SKWarpGeometryGrid {
    func deform(at contactPoint: float2) -> SKWarpGeometryGrid {
        // Make a copy of current grid positions.
        let currentPositions: [float2] = {
            var positions = [float2](repeating: .zero, count: vertexCount)
            (0..<vertexCount).forEach({ positions[$0] = destPosition(at: $0) })
            return positions
        }()
        
        // Move some of the positions in the grid close to contact point.
        let destination = currentPositions.map { (gridPoint) -> float2 in
            let contactDistance = gridPoint.distance(to: contactPoint)
            let deformationRadius: Float = 0.35
            guard contactDistance <= Float(deformationRadius) else { return gridPoint }
            // If contact was very close to the grid point, move it a little bit further away from the contact point.
            let maxDeformation: Float = 0.1
            let gridPointChangeFactor = (Float(deformationRadius) - contactDistance) / Float(deformationRadius)
            let gridPointDistanceChange = Float(maxDeformation) * gridPointChangeFactor // vector length
            
            // Limit angle, as otherwise the edges of the crater are too far away from the center of the node.
            let angleToCenter = contactPoint.angle(to: float2(x: 0.5, y: 0.5))
            let maxAngleOffset = Float.pi / 4.0
            let minAngle = angleToCenter - maxAngleOffset
            let maxAngle = angleToCenter + maxAngleOffset
            var gridPointOffsetAngle = contactPoint.angle(to: gridPoint)
            gridPointOffsetAngle = min(max(gridPointOffsetAngle, minAngle), maxAngle)
            
            return float2(x: gridPoint.x + gridPointDistanceChange * cos(gridPointOffsetAngle), y: gridPoint.y + gridPointDistanceChange * sin(gridPointOffsetAngle))
        }
        
        return replacingByDestinationPositions(positions: destination)
    }
}

extension CGPoint {
    func rotated(by angle: CGFloat, pivot: CGPoint) -> CGPoint {
        // Shift, rotate at origin, shift back.
        let x = (self.x - pivot.x) * cos(angle) - (self.y - pivot.y) * sin(angle) + pivot.x
        let y = (self.x - pivot.x) * sin(angle) + (self.y - pivot.y) * cos(angle) + pivot.y
        return CGPoint(x: x, y: y)
    }
    
    func normalizedContactPoint(_ pivotPoint: CGPoint, rotation: CGFloat) -> CGPoint {
        // Warp geometry is in node's local coordinates, therefore deformation needs to take account current rotation.
        let rotatedContactPoint = rotated(by: -rotation, pivot: pivotPoint)
        let dx = rotatedContactPoint.x - pivotPoint.x
        let dy = rotatedContactPoint.y - pivotPoint.y
        let deltaMax = max(abs(dx), abs(dy))
        // Normalise contact point (dx / deltaMax), gives a point in a rect of x:-1,y:-1,w:2,h:2. Therefore offset the point by 1.0 and convert it into unit rect, which finally gives the point in rect of x:0,y:0,w:1,h:1.
        return CGPoint(x: (dx / deltaMax + 1.0) / 2.0, y: (dy / deltaMax + 1.0) / 2.0)
    }
}

extension float2 {
    static var zero = float2(0, 0)
    
    func distance(to point: float2) -> Float {
        return (pow(point.x - x, 2) + pow(point.y - y, 2)).squareRoot()
    }
    
    func angle(to point: float2) -> Float {
        var angle = atan2(point.y - y, point.x - x)
        angle = (angle < 0) ? angle + 2.0 * .pi : angle
        angle = (angle > 2.0 * .pi) ? angle - 2.0 * .pi : angle
        return angle
    }
}

final class GameScene: SKScene {
    private let sprite = SKSpriteNode(imageNamed: "Circle")
    
    override func didMove(to view: SKView) {
        addChild(sprite)
        sprite.run(.repeatForever(.rotate(byAngle: .pi, duration: 5.0)))
    }
    
    func touchUp(atPoint position: CGPoint) {
        let gridContactPoint = position.normalizedContactPoint(sprite.position, rotation: sprite.zRotation)
        let grid = sprite.warpGeometry as? SKWarpGeometryGrid ?? SKWarpGeometryGrid(columns: 4, rows: 4)
        let deformedGrid = grid.deform(at: float2(Float(gridContactPoint.x), Float(gridContactPoint.y)))
        guard let action = SKAction.warp(to: deformedGrid, duration: 0.5) else { fatalError("Invalid deformation.") }
        action.timingMode = .easeOut
        sprite.run(action, withKey: "deform")
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { touchUp(atPoint: t.location(in: self)) }
    }
}

let sceneView = SKView(frame: CGRect(x:0 , y:0, width: 640, height: 480))
guard let scene = GameScene(fileNamed: "GameScene") else { fatalError() }
scene.scaleMode = .aspectFill
sceneView.presentScene(scene)
PlaygroundSupport.PlaygroundPage.current.liveView = sceneView
