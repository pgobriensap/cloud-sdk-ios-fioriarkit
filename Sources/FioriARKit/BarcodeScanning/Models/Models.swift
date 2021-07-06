//
//  Models.swift
//
//
//  Created by O'Brien, Patrick on 6/29/21.
//

import Foundation
import Vision

struct BarcodeModel: Identifiable, Hashable {
    var id: String
    var title: String
    var isDiscovered: Bool
    var symbology: VNBarcodeSymbology?
    
    internal init(id: String, title: String = "", isDiscovered: Bool = false, symbology: VNBarcodeSymbology? = nil) {
        self.id = id
        self.title = title
        self.isDiscovered = isDiscovered
        self.symbology = symbology
    }
    
    static let empty = BarcodeModel(id: "", title: "", isDiscovered: false, symbology: nil)
    
    var symbologyString: String {
        guard let symbology = symbology else {
            return ""
        }

        switch symbology {
        case .qr:
            return "QR"
        case .ean13:
            return "EAN-13"
        case .code128:
            return "Code-128"
        default:
            return ""
        }
    }
}
