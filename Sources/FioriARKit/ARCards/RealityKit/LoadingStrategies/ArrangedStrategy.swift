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
        let arrangement: [Float] = [-0.10, 0, 0.10]

        var count = 0
        for cardItem in self.cardContents {
            let internalEntity = ModelEntity(mesh: MeshResource.generateSphere(radius: 0.025), materials: [SimpleMaterial(color: .red, isMetallic: false)])
            internalEntity.generateCollisionShapes(recursive: true)
            internalEntity.position.x = arrangement[count]
            count += 1
            manager.sceneRoot!.addChild(internalEntity)
            let annotation = ScreenAnnotation(card: cardItem)
            annotation.setInternalEntity(with: internalEntity)
            manager.arView?.installGestures(for: internalEntity as! HasCollision)
            annotations.append(annotation)
        }
        
        return annotations
    }
}
