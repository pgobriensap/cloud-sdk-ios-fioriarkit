//
//  CaptureSessionView.swift
//
//
//  Created by O'Brien, Patrick on 6/24/21.
//

import AVFoundation
import Foundation
import SwiftUI
import Vision

internal struct CaptureSessionContainer: UIViewControllerRepresentable {
    @Binding var currentPayload: BarcodeModel
    @Binding var discoveredPayloads: Set<BarcodeModel>
    @Binding var neededBarcodes: [BarcodeModel]
    var hasCameraViewControls: Bool = true
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> BarcodeDetectionVC {
        let vc = BarcodeDetectionVC()
        vc.barcodeDelegate = context.coordinator
        vc.hasCameraViewControls = self.hasCameraViewControls
        return vc
    }
    
    func updateUIViewController(_ uiViewController: BarcodeDetectionVC, context: Context) {}
    
    class Coordinator: NSObject, BarcodeOutputDelegate {
        var parent: CaptureSessionContainer
        
        init(_ csVC: CaptureSessionContainer) {
            self.parent = csVC
        }
        
        func payloadOutput(payload: String, symbology: VNBarcodeSymbology) {
            let barcode = BarcodeModel(id: payload, symbology: symbology)
            self.parent.currentPayload = barcode
            self.parent.discoveredPayloads.insert(barcode)

            for (index, needed) in self.parent.neededBarcodes.enumerated() {
                if self.parent.discoveredPayloads.contains(where: { $0.id == needed.id }) {
                    self.parent.neededBarcodes[index].isDiscovered = true
                }
            }
        }
    }

    typealias UIViewControllerType = BarcodeDetectionVC
}
