//
//  SwiftUIView.swift
//
//
//  Created by O'Brien, Patrick on 2/15/21.
//

import SwiftUI

public protocol CardItemModel: Identifiable, TitleComponent, DescriptionTextComponent, DetailImageComponent, ActionTextComponent, IconComponent {}

public protocol TitleComponent {
    var title_: String { get }
}

public protocol DescriptionTextComponent {
    var descriptionText_: String? { get }
}

public protocol DetailImageComponent {
    var detailImage_: Image? { get }
}

public protocol ActionTextComponent {
    var actionText_: String? { get }
}

public protocol IconComponent {
    var icon_: Image? { get }
}

public struct DecodableCardItem: CardItemModel {
    public var id: String
    public var title_: String
    public var descriptionText_: String?
    public var detailImage_: Image?
    public var actionText_: String?
    public var icon_: Image?
    
    internal init(id: String, title_: String, descriptionText_: String? = nil, detailImage_: Image? = nil, actionText_: String? = nil, icon_: Image? = nil) {
        self.id = id
        self.title_ = title_
        self.descriptionText_ = descriptionText_
        self.detailImage_ = detailImage_
        self.actionText_ = actionText_
        self.icon_ = icon_
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case title_
        case descriptionText_
        case detailImage_
        case actionText_
        case icon_
    }
}

extension DecodableCardItem: Decodable {
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try values.decode(String.self, forKey: .id)
        self.title_ = try values.decode(String.self, forKey: .title_)
        self.descriptionText_ = try values.decode(String?.self, forKey: .descriptionText_)
        let imageData: Data? = try values.decode(Data?.self, forKey: .detailImage_)
        var image: Image?
        if let unwrappedImageData = imageData {
            if let uiImage = UIImage(data: unwrappedImageData) {
                image = Image(uiImage: uiImage)
            } else {
                throw LoadingStrategyError.base64DecodingError
            }
        }
        self.detailImage_ = image
        self.actionText_ = try values.decode(String?.self, forKey: .actionText_)
        let iconString: String? = try values.decode(String?.self, forKey: .icon_)
        self.icon_ = iconString != nil ? Image(systemName: iconString!) : nil
    }
}

public struct SimpleCardItem: CardItemModel {
    public var id: String
    public var title_: String
    public var descriptionText_: String?
    public var detailImage_: Image?
    public var actionText_: String?
    public var icon_: Image?
    
    public init(id: String, title_: String, descriptionText_: String? = nil, detailImage_: Image? = nil, actionText_: String? = nil, icon_: Image? = nil) {
        self.id = id
        self.title_ = title_
        self.descriptionText_ = descriptionText_
        self.detailImage_ = detailImage_
        self.actionText_ = actionText_
        self.icon_ = icon_
    }
}
