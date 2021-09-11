//
//  Models.swift
//
//
//  Created by O'Brien, Patrick on 6/29/21.
//

import Foundation
import Vision

struct BarcodeModel: Identifiable, Hashable {
    static let oneDimensionalBarcodes: [VNBarcodeSymbology] = [.ean13, .ean8, .code128, .code39, .upce]
    static let twoDimensionalBarcodes: [VNBarcodeSymbology] = [.qr]
    static let acceptedBarcodes = oneDimensionalBarcodes + twoDimensionalBarcodes
    static let empty = BarcodeModel(id: "", title: "", isDiscovered: false, symbology: nil)

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
    
    var symbologyString: String {
        guard let symbology = symbology else {
            return ""
        }

        switch symbology {
        case .qr:
            return "QR"
        case .ean13:
            return "EAN-13"
        case .ean8:
            return "EAN-8"
        case .code128:
            return "Code-128"
        case .code39:
            return "Code-39"
        case .upce:
            return "UPCE"
        default:
            return ""
        }
    }
}

enum Resolution {
    static let normal = CGSize(width: 1920, height: 1080)
    static let hd = CGSize(width: 4032, height: 3024)
}

struct Extent {
    var position: CGPoint
    var size: CGSize
}
