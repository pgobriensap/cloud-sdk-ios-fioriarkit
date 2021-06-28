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
    @Binding var currentPayload: String
    @Binding var discoveredPayloads: Set<String>
    @Binding var neededBarcodes: [BarcodeModel]
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> CaptureSessionVC {
        let vc = CaptureSessionVC()
        vc.barcodeDelegate = context.coordinator
        return vc
    }
    
    func updateUIViewController(_ uiViewController: CaptureSessionVC, context: Context) {}
    
    class Coordinator: NSObject, BarcodeOutputDelegate {
        var parent: CaptureSessionContainer
        
        init(_ csVC: CaptureSessionContainer) {
            self.parent = csVC
        }
        
        func payloadOutput(payload: String) {
            self.parent.currentPayload = payload
            self.parent.discoveredPayloads.insert(payload)

            for (index, needed) in self.parent.neededBarcodes.enumerated() {
                if self.parent.discoveredPayloads.contains(needed.id) {
                    self.parent.neededBarcodes[index].isDiscovered = true
                }
            }
        }
    }

    typealias UIViewControllerType = CaptureSessionVC
}
