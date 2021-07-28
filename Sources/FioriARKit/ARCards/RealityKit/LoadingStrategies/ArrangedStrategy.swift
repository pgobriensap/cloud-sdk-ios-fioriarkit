//
//  VectorStrategy.swift
//
//
//  Created by O'Brien, Patrick on 6/22/21.
//

import ARKit
import Foundation
import RealityKit
import SwiftUI

public struct ArrangedStrategy<CardItem: CardItemModel>: AnnotationLoadingStrategy where CardItem.ID: LosslessStringConvertible {
    public var cardContents: [CardItem]
    public var anchorImage: UIImage
    public var physicalWidth: CGFloat
    
    public init(cardContents: [CardItem], anchorImage: UIImage, physicalWidth: CGFloat) {
        self.cardContents = cardContents
        self.anchorImage = anchorImage
        self.physicalWidth = physicalWidth
    }
    
    public func load(with manager: ARManagement) throws -> [ScreenAnnotation<CardItem>] {
        var annotations = [ScreenAnnotation<CardItem>]()

        manager.sceneRoot = Entity()
        manager.addReferenceImage(for: self.anchorImage, with: self.physicalWidth)
        let arrangement: [Float] = self.getArrangement(count: self.cardContents.count, increment: 0.1)

        for (index, cardItem) in self.cardContents.enumerated() {
            let internalEntity = ModelEntity(mesh: MeshResource.generateSphere(radius: 0.035), materials: [SimpleMaterial(color: .red, isMetallic: false)])
            internalEntity.generateCollisionShapes(recursive: true)
            internalEntity.position.x = arrangement[index]
            manager.sceneRoot!.addChild(internalEntity)
            let annotation = ScreenAnnotation(card: cardItem)
            annotation.setInternalEntity(with: internalEntity)
            manager.arView?.installGestures([.scale, .translation], for: internalEntity)
            annotations.append(annotation)
        }
        
        return annotations
    }
    
    private func getArrangement(count: Int, increment: Float) -> [Float] {
        var arrangement: [Float] = []
        
        var current: Float = (Float(count / 2) / 10.0) * -1
        print(current)
        for _ in 0 ..< count {
            arrangement.append(current)
            current += increment
        }
        return arrangement
    }
}
