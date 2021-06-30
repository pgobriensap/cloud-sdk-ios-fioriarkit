//
//  ScreenAnnotation.swift
//
//
//  Created by O'Brien, Patrick on 3/16/21.
//

import CoreGraphics
import RealityKit
import SwiftUI

/// Wrapper struct for the **CardItem : CardItemModel**  and the real world anchoring position. Used to set the internal entity.

public struct ScreenAnnotation<CardItem: CardItemModel>: Identifiable, Equatable {
    public var id: CardItem.ID {
        self.card.id
    }
    
    public var icon: Image? {
        self.card.icon_
    }
    
    public var card: CardItem
    
    public internal(set) var isMarkerVisible: Bool
    public internal(set) var isCardVisible: Bool
    
    internal var marker: MarkerAnchor
    internal var screenPosition: CGPoint
    internal var isSelected: Bool

    public init(card: CardItem, isMarkerVisible: Bool = false, isCardVisible: Bool = true, isSelected: Bool = false) {
        self.marker = MarkerAnchor()
        self.card = card
        self.isMarkerVisible = isMarkerVisible
        self.isCardVisible = isCardVisible
        self.screenPosition = CGPoint(x: -200, y: -200)
        self.isSelected = isSelected
    }
    
    /// Sets the internal within the MarkerAnchor
    public func setInternalEntity(with entity: Entity) {
        self.marker.internalEnitity = entity
        // (marker.internalEnitity as? HasCollision)?.generateCollisionShapes(recursive: true)
    }
    
    internal mutating func setMarkerVisibility(to isVisible: Bool) {
        self.isMarkerVisible = isVisible
    }
    
    internal mutating func setCardVisibility(to isVisible: Bool) {
        self.isCardVisible = isVisible
    }
    
    internal mutating func setInternalEntityVisibility(to isVisible: Bool) {
        isVisible ? self.marker.showInternalEntity() : self.marker.hideInternalEntity()
    }
    
//    internal func generateEntityCollisionShapes(recursive: Bool = true) {
//        marker.internalEnitity.generateCollisionShapes(recursive: recursive)
//    }
    
    public static func == (lhs: ScreenAnnotation<CardItem>, rhs: ScreenAnnotation<CardItem>) -> Bool {
        lhs.id == rhs.id
    }
}
