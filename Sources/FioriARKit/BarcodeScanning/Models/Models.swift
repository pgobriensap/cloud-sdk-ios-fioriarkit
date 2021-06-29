//
//  Models.swift
//
//
//  Created by O'Brien, Patrick on 6/29/21.
//

import Foundation
import Vision

struct BarcodeModel: Identifiable {
    var id: String
    var title: String
    var isDiscovered: Bool
    var symbology: VNBarcodeSymbology
}
